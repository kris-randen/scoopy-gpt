//
//  ScoopyViewModel.swift
//  scoopy-gpt
//
//  Created by Krishnaswami Rajendren on 1/13/24.
//

import Foundation
import AVFoundation
import Observation
import XCAOpenAIClient

@Observable
class ScoopyViewModel: NSObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    let client = OpenAIClient(apiKey: Constants.api_key)
    var player: AVAudioPlayer!
    var recorder: AVAudioRecorder!
    var session = AVAudioSession.sharedInstance()
    
    ///Determine when the user has stopped talking automatically without a button
    var animationTimer: Timer?
    var recordingTimer: Timer?
    var audioPower = 0.0
    var prevAudioPower: Double?
    var speechProcessingTask: Task<Void, Never>?
    
    var voice = Voice.alloy
    
    var captureURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("scoopyRecording.m4a")
    }
    
    var state = ScoopyState.idle {
        didSet { print(state) }
    }
    
    var isIdle: Bool {
        guard case .idle = state else { return false }
        return true

    }
    
    var siriWaveFormOpacity: CGFloat {
        switch state {
        case .recording, .playing:
            return 1
        default:
            return 0
        }
    }
    
    override init() {
        super.init()
        do {
            #if os(iOS)
            try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
            #else
            try session.setCategory(.playAndRecord, mode: .default)
            #endif
            try session.setActive(true)
            AVAudioApplication.requestRecordPermission { [unowned self] allowed in
                if !allowed { self.state = .error("Mic access unavailable. Please provide mic access in setting.")}
            }
        } catch {
            setState(to: .error(error))
        }
    }
    
    func startAudioCapture() {
        reset()
        setState(to: .recording)
        print("Starting audio capture state set to \(state)")
        do {
            recorder = try AVAudioRecorder(url: captureURL, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            recorder.isMeteringEnabled = true
            recorder.delegate = self
            recorder.record()
            setRecordingAnimationTimer()
            setRecordingTimer()
        } catch {
            reset()
            setState(to: .error(error))
        }
    }
    
    private func finishAudioCapture() {
        reset()
        do {
            let audio = try Data(contentsOf: captureURL)
            speechProcessingTask = processSpeechTask(for: audio)
        } catch {
            setState(to: .error(error))
            reset()
        }
    }
    
    private func processSpeechTask(for audio: Data) -> Task<Void, Never> {
        Task { @MainActor [unowned self] in
            do {
                self.state = .processing
                let prompt = try await client.generateAudioTransciptions(audioData: audio)
                print("Audio transcript generated")
                
                try Task.checkCancellation()
                let responseText = try await client.promptChatGPT(prompt: prompt, model: .gpt_hyphen_3_period_5_hyphen_turbo)
                print("Response text received")
                
                try Task.checkCancellation()
                let responseAudio = try await client.generateSpeechFrom(input: responseText, voice: .init(rawValue: voice.rawValue) ?? .alloy)
                print("Response audio generated")
                
                try Task.checkCancellation()
                try self.playAudio(from: responseAudio)
            } catch {
                if Task.isCancelled { return }
                setState(to: .error(error))
                reset()
            }
        }
    }
    
    func cancelRecording() {
        resetAll()
    }
    
    func cancelProcessingTask() {
        resetSpeechTask()
        resetAll()
    }
    
    private func resetSpeechTask() {
        speechProcessingTask?.cancel()
        speechProcessingTask = nil
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { resetAll() }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        resetAll()
    }
    
    
    
    private func resetState() {
        setState()
    }
    
    private func setState(to state: ScoopyState = .idle) {
        self.state = state
    }
    
    private func setRecordingAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self] _ in
            guard self.recorder != nil else { return }
            self.recorder.updateMeters()
            let power = min(1, max(0, 1 - abs(Double(self.recorder.averagePower(forChannel: 0)) / 50)))
            self.audioPower = power
        })
    }
    
    private func setPlayingAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self] _ in
            guard self.player != nil else { return }
            self.player.updateMeters()
            let power = min(1, max(0, 1 - abs(Double(self.player.averagePower(forChannel: 0)) / 160)))
            self.audioPower = power
        })
    }
    
    private func setRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true, block: { [unowned self] _ in
            guard self.recorder != nil else { return }
            self.recorder.updateMeters()
            let power = min(1, max(0, 1 - abs(Double(self.recorder.averagePower(forChannel: 0)) / 50)))
            if self.prevAudioPower == nil {
                self.prevAudioPower = power
                return
            }
            if let prevAudioPower = self.prevAudioPower, prevAudioPower < 0.25 && power < 0.175 {
                self.finishAudioCapture()
                return
            }
            self.prevAudioPower = power
        })
    }
    
    private func playAudio(from data: Data) throws {
        setState(to: .playing)
        player = try AVAudioPlayer(data: data)
        player.isMeteringEnabled = true
        player.delegate = self
        player.play()
        setPlayingAnimationTimer()
    }
    
    private func resetAll() {
        reset()
        resetState()
    }
    
    private func reset() {
        resetPower()
        resetRecorder()
        resetPlayer()
        resetRecordingTimer()
        resetAnimationTimer()
    }
    
    private func resetPower() {
        audioPower = 0
        prevAudioPower = nil
    }
    
    private func resetRecorder() {
        recorder?.stop()
        recorder = nil
    }
    
    private func resetPlayer() {
        player?.stop()
        player = nil
    }
    
    private func resetRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func resetAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}
