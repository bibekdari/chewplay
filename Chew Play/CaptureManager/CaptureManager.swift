//
//  CaptureManager.swift
//  Chew Play
//
//  Created by bibek timalsina on 02/02/2024.
//

import UIKit
import Combine

protocol CaptureManager {
    var store: Store { get }
    var previewLayer: CALayer? { get }
    var chew: AnyPublisher<ChewState, Never> { get }
    var progress: AnyPublisher<Int, Never> { get }
    func setup(_ hasValidPlayback: (() async -> Bool)?)
    func setOnSetPreviewLayer(_ value: ((CALayer) -> Void)?)
}

enum ChewState {
    case ok
    case recheck
    case reward
}
