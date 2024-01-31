//
//  ViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 28/01/2024.
//

import AVFoundation
import UIKit
import Vision
import WebKit

class LiveFeedViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
//    private var faceLayers: [CAShapeLayer] = []
    private let indicator = UIView()
    private let webview = WKWebView()
    private var oldArea: Double?
    private var timer: Timer?
    private var check = true
    private var time: Double = 0 {
        didSet {
            if time >= 5 {
                let sampleCount = movingTracked.count
                let lowerBound = sampleCount * 30 / 100 // 30%
                let trueSamples = movingTracked.filter({ $0 }).count
                isChewing = trueSamples >= lowerBound
                
                movingTracked = []
                time = 0
            }
        }
    }
    private var movingTracked: [Bool] = []
//    {
//        didSet {
//            if movingTracked.contains(true) {
//                isChewing = true
//                movingTracked = []
//                time = 0
//            }
//        }
//    }
    private var isChewing = false {
        didSet {
            if isChewing {
                indicator.backgroundColor = .green
                webview.setAllMediaPlaybackSuspended(false)
            } else {
                indicator.backgroundColor = .red
                webview.setAllMediaPlaybackSuspended(true)
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        DispatchQueue.global().async {
            self.captureSession.startRunning()
        }

        webview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webview)
        NSLayoutConstraint.activate([
            webview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webview.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webview.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        webview.configuration.allowsInlineMediaPlayback = true
        let request = URLRequest(url: URL(string: "https://www.youtube.com/")!)
        webview.load(request)

        indicator.backgroundColor = .red
        indicator.layer.cornerRadius = 10
        indicator.clipsToBounds = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.heightAnchor.constraint(equalToConstant: 20),
            indicator.widthAnchor.constraint(equalToConstant: 20)
        ])
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.time += 0.25
            self.check = true
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }
    
    private func setupCamera() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        if let device = deviceDiscoverySession.devices.first {
            device.set(frameRate: 0.25, device: device)

            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                    setupPreview()
                }
            }
        }
    }
    
    private func setupPreview() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
        
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]

        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        let videoConnection = self.videoDataOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
    }
}

extension LiveFeedViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
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
//                self.faceLayers.forEach({ drawing in drawing.removeFromSuperlayer() })

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
        guard !observations.isEmpty else {
            movingTracked.append(false)
            return
        }
        for observation in observations {
            let faceRectConverted = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
            let faceRectanglePath = CGPath(rect: faceRectConverted, transform: nil)
            
//            let faceLayer = CAShapeLayer()
//            faceLayer.path = faceRectanglePath
//            faceLayer.fillColor = UIColor.clear.cgColor
//            faceLayer.strokeColor = UIColor.yellow.cgColor
//
//            self.faceLayers.append(faceLayer)
//            self.view.layer.addSublayer(faceLayer)
            
            //FACE LANDMARKS
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
//            print(oldArea, "...", newArea, "...", ratio)
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
        let landmarkPath = CGMutablePath()
        let landmarkPathPoints = eye.normalizedPoints
            .map({ eyePoint in
                CGPoint(
                    x: eyePoint.y * faceBoundingBox.height + faceBoundingBox.origin.x,
                    y: eyePoint.x * faceBoundingBox.width + faceBoundingBox.origin.y)
            })
//        landmarkPath.addLines(between: landmarkPathPoints)
//        landmarkPath.closeSubpath()
//        let landmarkLayer = CAShapeLayer()
//        landmarkLayer.path = landmarkPath
//        landmarkLayer.fillColor = UIColor.clear.cgColor
//        landmarkLayer.strokeColor = UIColor.green.cgColor

//        self.faceLayers.append(landmarkLayer)
//        self.view.layer.addSublayer(landmarkLayer)
        return landmarkPathPoints
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

