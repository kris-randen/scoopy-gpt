//
//  Protocols.swift
//  scoopy-gpt
//
//  Created by Krishnaswami Rajendren on 1/14/24.
//

import Foundation

protocol RectangleProperties {
    var origin: CGPoint { get }
    var width: CGFloat { get }
    var height: CGFloat { get }
    var minDim: CGFloat { get }
}

protocol RoundedRectProperties: RectangleProperties {
    var x: CGFloat { get }
    var y: CGFloat { get }
    var radiusScaling: CGFloat { get }
    var orientation: CGRect.Orientation { get }
}
