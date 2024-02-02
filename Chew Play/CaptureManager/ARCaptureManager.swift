//
//  ARCaptureManager.swift
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
        $isChewingSubject.eraseToAnyPublisher()
    }
    var previewLayer: CALayer? { nil }
    var progress: AnyPublisher<Float, Never> {
        $time.map {[weak self] in
            guard let self else { return 0.0 }
            return Float($0 / Double(self.store.resetTimeInterval))
        }.eraseToAnyPublisher()
    }
    
    private var onSetPreviewLayer: ((CALayer) -> ())?
    private let session = ARSession()
    private var timer: Timer?
    private var check = true
    @Published private var time: Double = 0 {
        didSet {
            if time >= Double(store.resetTimeInterval) {
                isChewingSubject = chewedCount >= store.noOfChews
                chewedCount = 0
                time = 0
            }
        }
    }
    private var aboveUpperLimit = false {
        didSet {
            if aboveUpperLimit == true && oldValue == false {
                chewedCount += 1
            }
        }
    }
    
    private var chewedCount = 0
    
    @Published private var isChewingSubject = false
    
    deinit {
        timer?.invalidate()
    }
    
    private var isChewingCancellable: AnyCancellable?

    func setup() {
        session.delegate = self
        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        isChewingSubject = true
        isChewingCancellable = $isChewingSubject.sink { [weak self] value in
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
        
        aboveUpperLimit = jawOpen > store.sensitivity * 0.5
    }
}
