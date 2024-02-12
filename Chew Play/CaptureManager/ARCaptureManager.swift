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
    let store: Store
    var chew: AnyPublisher<ChewState, Never> {
        $chewSubject.eraseToAnyPublisher()
    }
    var previewLayer: CALayer? { nil }
    var progress: AnyPublisher<Int, Never> {
        $time.map(Int.init).eraseToAnyPublisher()
    }
    
    private var hasValidPlayback: (() async -> Bool)?
    private var onSetPreviewLayer: ((CALayer) -> ())?
    private let session = ARSession()
    private var timer: Timer?
    private var aboveUpperLimit = false {
        didSet {
            if aboveUpperLimit == true && oldValue == false {
                chewedCount += 1
            }
        }
    }
    private var chewedCount = 0
    
    @Published private var time: Double = 0
    @Published private var chewSubject = ChewState.reward
    
    deinit {
        timer?.invalidate()
        session.pause()
        rewardWaitTask?.cancel()
    }
    
    init(store: Store) {
        self.store = store
        super.init()
    }
    
    private var isChewingCancellable: AnyCancellable?
    private var rewardWaitTask: Task<Void, Never>?

    func setup(_ hasValidPlayback: (() async -> Bool)?) {
        self.hasValidPlayback = hasValidPlayback
        session.delegate = self
        
        isChewingCancellable = $chewSubject.sink { [weak self] in
            guard let self else { return }
            if $0 == .reward {
                self.time = Double(self.store.rewardTime)
                self.session.pause()
                self.rewardWaitTask?.cancel()
                self.rewardWaitTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(self?.store.rewardTime ?? 0))
                    guard !Task.isCancelled,
                          await self?.hasValidPlayback?() ?? false,
                          !Task.isCancelled,
                          let self = self else {
                        self?.chewSubject = .reward
                        return
                    }
                    self.time = 0
                    let config = ARFaceTrackingConfiguration()
                    config.maximumNumberOfTrackedFaces = 1
                    self.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                    self.chewSubject = .ok
                }
            }
        }
        setTimer()
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
                if self.chewSubject == .reward {
                    self.time -= self.store.observationTimeInterval
                } else {
                    self.time += self.store.observationTimeInterval
                    if self.time >= Double(self.store.resetTimeInterval) {
                        self.time = 0
                        self.chewSubject = self.chewedCount >= self.store.noOfChews ? .reward : .recheck
                        self.chewedCount = 0
                    }
                }
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
