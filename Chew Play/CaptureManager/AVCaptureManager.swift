//
//  AVCaptureManager.swift
//  Chew Play
//
//  Created by bibek timalsina on 02/02/2024.
//

import Foundation
import AVFoundation
import Vision
import Combine

class AVCaptureManager: NSObject, CaptureManager {
    func setOnSetPreviewLayer(_ value: ((CALayer) -> Void)?) {
        self.onSetPreviewLayer = value
    }
    let store: Store
    var chew: AnyPublisher<ChewState, Never> {
        $chewSubject.eraseToAnyPublisher()
    }
    var previewLayer: CALayer? { avCaptureVideoPreviewLayer }
    var progress: AnyPublisher<Int, Never> {
        $time.map(Int.init).eraseToAnyPublisher()
    }
    
    private var onSetPreviewLayer: ((CALayer) -> ())?
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private(set) var avCaptureVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var oldArea: Double?
    private var timer: Timer?
    private var check = true
    @Published private var time: Double = 0
    private var movingTracked: [Bool] = []
    @Published private var chewSubject = ChewState.reward
    
    deinit {
        timer?.invalidate()
        captureSession.stopRunning()
    }
    
    init(store: Store) {
        self.store = store
        super.init()
    }
    
    private var chewSubjectCancellable: AnyCancellable?
    private var rewardWaitTask: Task<Void, Never>?
    
    func setup() {
        Task { @MainActor in
            guard await setupCamera() else { return }
            chewSubjectCancellable = $chewSubject.sink { [weak self] in
                guard let self else { return }
                if $0 == .reward {
                    self.time = Double(self.store.rewardTime)
                    DispatchQueue.global(qos: .userInitiated).async {
                        if self.captureSession.isRunning {
                            self.captureSession.stopRunning()
                        }
                    }
                    self.rewardWaitTask?.cancel()
                    self.rewardWaitTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: NSEC_PER_SEC * UInt64(self?.store.rewardTime ?? 0))
                        guard !Task.isCancelled,
                              let self = self else {
                            return
                        }
                        self.time = 0
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.captureSession.startRunning()
                        }
                        self.chewSubject = .ok
                    }
                }
            }
            setTimer()
        }
    }
    
    private func setupCamera() async -> Bool {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        if let device = deviceDiscoverySession.devices.first {
            device.set(frameRate: 0.25, device: device)

            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                    await setupPreview(captureSession)
                    return true
                }
            }
        }
        return false
    }
    
    @MainActor
    private func setupPreview(_ captureSession: AVCaptureSession) async {
        let previewLayer = await Task(priority: .userInitiated) { AVCaptureVideoPreviewLayer(session: captureSession) }.value
        
        self.avCaptureVideoPreviewLayer = previewLayer
        previewLayer.videoGravity = .resizeAspectFill
        self.onSetPreviewLayer?(previewLayer)
        
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        let videoConnection = self.videoDataOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
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
                        let totalChews = self.movingTracked.filter({ $0 }).count
                        self.chewSubject = totalChews >= self.store.noOfChews ? .reward : .recheck
                        self.movingTracked = []
                        self.time = 0
                    }
                    self.check = true
                }
            }
        )
    }
}


extension AVCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        guard check else {
            return
        }
        check = false
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let observations = request.results as? [VNFaceObservation] {
                    self.handleFaceDetectionObservations(observations: observations)
                }
            }
        })
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .leftMirrored, options: [:])
        
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func handleFaceDetectionObservations(observations: [VNFaceObservation]) {
        guard !observations.isEmpty, let avCaptureVideoPreviewLayer else {
            movingTracked.append(false)
            return
        }
        for observation in observations {
            let faceRectConverted = avCaptureVideoPreviewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
            if let innerLips = observation.landmarks?.innerLips {
                let landmarkPoints = self.handleLandmark(innerLips, faceBoundingBox: faceRectConverted)
                checkMovingMouth(innerLipsLandmarkPoints: landmarkPoints)
            }
        }
    }
    
    private func checkMovingMouth(innerLipsLandmarkPoints: [CGPoint]) {
        let newArea = getArea(points: innerLipsLandmarkPoints)
        if let oldArea {
            let ratio = abs(oldArea - newArea)/oldArea
            movingTracked.append(ratio > 2)
        }
        oldArea = newArea
    }
    
    func getArea(points: [CGPoint]) -> Double {
        guard points.count > 2 else {
            return 0
        }
        let totalTriangles = points.count - 2
        return (0..<totalTriangles)
            .reduce(0.0) { partialArea, index in
                let p1 = points[0]
                let p2 = points[index + 1]
                let p3 = points[index + 2]
                let a = distance(p1: p1, p2: p2)
                let b = distance(p1: p1, p2: p3)
                let c = distance(p1: p2, p2: p3)
                return partialArea + self.area(a: a, b: b, c: c)
            }
    }
    
    private func area(a: Double, b: Double, c: Double) -> Double {
        let s = (a + b + c)/2
        return sqrt(s * (s - a) * (s - b) * (s - c))
    }
    
    private func distance(p1: CGPoint, p2: CGPoint) -> Double {
        let p1p2x: Double = (p1.x - p2.x) * (p1.x - p2.x)
        let p1p2y: Double = (p1.y - p2.y) * (p1.y - p2.y)
        return sqrt(p1p2x + p1p2y)
    }
    
    private func handleLandmark(_ eye: VNFaceLandmarkRegion2D, faceBoundingBox: CGRect) -> [CGPoint] {
        eye.normalizedPoints
            .map({ eyePoint in
                CGPoint(
                    x: eyePoint.y * faceBoundingBox.height + faceBoundingBox.origin.x,
                    y: eyePoint.x * faceBoundingBox.width + faceBoundingBox.origin.y)
            })
    }
}

extension AVCaptureDevice {
    func set(frameRate: Double, device: AVCaptureDevice) {
        guard let range = device.activeFormat.videoSupportedFrameRateRanges.first else {
            print("Requested FPS is not supported by the device's activeFormat !")
            return
        }
        let fr: Double
        if range.minFrameRate...range.maxFrameRate ~= frameRate {
            fr = frameRate
        } else {
            fr = range.minFrameRate
        }

        do {
            try lockForConfiguration()
            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(fr))
            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(fr))
            unlockForConfiguration()
        } catch {
            print("LockForConfiguration failed with error: \(error.localizedDescription)")
        }
    }
}
