//
//  LiveFeedViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 28/01/2024.
//

import Foundation
import ARKit
import Combine

class ARCaptureManager: NSObject, CaptureManager {
    func setOnSetPreviewLayer(_ value: ((CALayer) -> Void)?) {
        self.onSetPreviewLayer = value
    }
    let store = Store()
    var isChewing: AnyPublisher<Bool, Never> {
        isChewingSubject.eraseToAnyPublisher()
    }
    var previewLayer: CALayer? { nil }
    
    private var onSetPreviewLayer: ((CALayer) -> ())?
    private let session = ARSession()
    private var timer: Timer?
    private var check = true
    private var time: Double = 0 {
        didSet {
            if time >= Double(store.resetTimeInterval) {
                let totalChews = movingTracked.filter({ $0 }).count
                isChewingSubject.send(totalChews >= store.noOfChews)
                movingTracked = []
                time = 0
            }
        }
    }
    private var movingTracked: [Bool] = []
    
    private var isChewingSubject = CurrentValueSubject<Bool, Never>(false)
    
    deinit {
        timer?.invalidate()
    }
    
    private var isChewingCancellable: AnyCancellable?

    func setup() {
        session.delegate = self
        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        isChewingSubject.send(true)
        isChewingCancellable = isChewingSubject.sink { [weak self] value in
            guard let self else { return }
            if value {
                let reward = max((self.store.rewardTime - self.store.resetTimeInterval), self.store.resetTimeInterval)
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(reward))) { [weak self] in
                    self?.setTimer()
                }
            }
        }
    }
    
    private func setTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: store.observationTimeInterval,
            repeats: true,
            block: { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.time += self.store.observationTimeInterval
                self.check = true
            }
        )
    }
}

extension ARCaptureManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard
            let faceAnchor = anchors.compactMap({$0 as? ARFaceAnchor}).first,
            let jawOpen = faceAnchor.blendShapes[.jawOpen] as? Float
        else {
            return
        }
        
        if jawOpen > store.sensitivity * 0.5 {
            movingTracked.append(true)
        }else if jawOpen < 0.025 {
            movingTracked.append(false)
        }else {
            movingTracked.append(false)
        }
    }
}
