//
//  Models.swift
//  scoopy-gpt
//
//  Created by Krishnaswami Rajendren on 1/13/24.
//

import Foundation

enum Voice: String, Codable, Hashable, Sendable, CaseIterable {
    case alloy
    case echo
    case fable
    case onyx
    case nova
    case shimmer
}

enum ScoopyState {
    case idle
    case recording
    case processing
    case playing
    case error(Error)
}
