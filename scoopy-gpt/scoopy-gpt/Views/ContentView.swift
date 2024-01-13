//
//  ContentView.swift
//  scoopy-gpt
//
//  Created by Krishnaswami Rajendren on 1/13/24.
//

import SwiftUI
import SiriWaveView

struct ContentView: View {
    @State var vm = ScoopyViewModel()
    @State var isProcessing = false
    
    var body: some View {
        VStack {
            Text("𝘀𝗰𝗼𝗼𝗽𝗒🦉🌈 𝙶𝙿𝚃 🤖")
                .font(.title2)
            
            Spacer()
            siriWaveView
            Spacer()
            captureButton
            cancelButton
            errorView
        }
        .padding()
        .foregroundStyle(Colors.scoopRed)
    }
    
    var siriWaveView: some View {
        SiriWaveView()
            .power(power: vm.audioPower)
            .opacity(vm.siriWaveFormOpacity)
            .frame(height: Constants.Height / 4)
            .overlay {
                overlayView
            }
    }
    
    @ViewBuilder
    var overlayView: some View {
        switch vm.state {
        case .processing:
            Image(systemName: "brain")
                .font(.system(size: 98))
                .symbolEffect(.bounce.up.byLayer, options: .repeating, value: isProcessing)
                .onAppear{ isProcessing = true }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    var captureButton: some View {
        switch vm.state {
        case .idle, .error:
            startCaptureButton
        default:
            EmptyView()
        }
    }
    
    var startCaptureButton: some View {
        Button {
            print("Capture Button Pressed")
            vm.startAudioCapture()
        } label: {
            Image(systemName: "mic.fill.badge.plus")
                .font(.largeTitle)
                .buttonStyle(.borderless)
        }
    }
    
    @ViewBuilder
    var cancelButton: some View {
        switch vm.state {
        case .recording:
            cancelRecordingButton
        case .processing, .playing:
            cancelProcessingButton
        default:
            EmptyView()
        }
    }
    
    var cancelProcessingButton: some View {
        Button(role: .destructive) {
            vm.cancelProcessingTask()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.largeTitle)
        }
        .buttonStyle(.borderless)
    }
    
    var cancelRecordingButton: some View {
        Button(role: .destructive) {
            vm.cancelRecording()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.largeTitle)
        }
        .buttonStyle(.borderless)
    }
    
    @ViewBuilder
    var errorView: some View {
        if case let .error(error) = vm.state {
            Text(error.localizedDescription)
                .font(Fonts.signInTextField)
                .lineLimit(2)
        }
        else {
            EmptyView()
        }
    }
}

#Preview("Idle") {
    ContentView()
}

#Preview("Recording") {
    let vm = ScoopyViewModel()
    vm.state = .recording
    vm.audioPower = 0.15
    return ContentView(vm: vm)
}

#Preview("Processing") {
    let vm = ScoopyViewModel()
    vm.state = .processing
    return ContentView(vm: vm)
}

#Preview("Playing") {
    let vm = ScoopyViewModel()
    vm.state = .playing
    vm.audioPower = 0.3
    return ContentView(vm: vm)
}

#Preview("Error") {
    let vm = ScoopyViewModel()
    vm.state = .error("An error has occured")
    return ContentView(vm: vm)
}

