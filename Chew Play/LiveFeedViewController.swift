//
//  LiveFeedViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 28/01/2024.
//

import AVFoundation
import UIKit
import Vision
import WebKit

class LiveFeedViewController: UIViewController {
    private let store = Store()
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoDataOutput = AVCaptureVideoDataOutput()
//    private var faceLayers: [CAShapeLayer] = []
    private let headerView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    private let textField: UITextField = {
        let textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(string: "Your URL", attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray])
        textField.clearButtonMode = .whileEditing
        textField.keyboardType = .URL
        textField.returnKeyType = .go
        return textField
    }()
//    private let indicator = UIImageView(image: .init(systemName: "circle.fill")?.withAlignmentRectInsets(.init(top: -8, left: -8, bottom: -8, right: -8)))
    private let indicator = UIImageView(image: .init(systemName: "globe")?.withAlignmentRectInsets(.init(top: -8, left: -8, bottom: -8, right: -8)))
    private let webview = WKWebView()
    private var oldArea: Double?
    private var timer: Timer?
    private var check = true
    private var time: Double = 0 {
        didSet {
            if time >= store.resetTimeInterval {
                let totalChews = movingTracked.filter({ $0 }).count
                isChewing = totalChews >= store.noOfChews
                movingTracked = []
                time = 0
            }
        }
    }
    private var movingTracked: [Bool] = []
    
    private var isChewing = false {
        didSet {
            if isChewing {
                indicator.tintColor = .green
                webview.setAllMediaPlaybackSuspended(false)
            } else {
                indicator.tintColor = .red
                webview.setAllMediaPlaybackSuspended(true)
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera() {
            if $0 {
                DispatchQueue.global().async {
                    self.captureSession.startRunning()
                }
            }
        }
        isChewing = false
        
        textField.delegate = self
        
        view.addSubview(headerView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 40),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        
        headerView.addArrangedSubview(indicator)
//        let globeIcon = UIImageView(image: .init(systemName: "globe")?.withAlignmentRectInsets(.init(top: -8, left: -8, bottom: -8, right: -8)))
//        globeIcon.contentMode = .scaleAspectFit
//        headerView.addArrangedSubview(globeIcon)
        
        headerView.addArrangedSubview(textField)
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(.init(systemName: "xmark"), for: .normal)
        button.addAction(UIAction(handler: { [weak self] _ in
            self?.dismiss(animated: true)
        }), for: .touchUpInside)
        headerView.addArrangedSubview(button)
        
        NSLayoutConstraint.activate([
//            globeIcon.widthAnchor.constraint(equalTo: globeIcon.heightAnchor),
            indicator.widthAnchor.constraint(equalTo: indicator.heightAnchor),
            button.widthAnchor.constraint(equalTo: button.heightAnchor)
        ])

        webview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webview)
        NSLayoutConstraint.activate([
            webview.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            webview.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webview.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        webview.configuration.allowsInlineMediaPlayback = true
        let request = URLRequest(url: URL(string: "https://www.youtube.com/")!)
        webview.load(request)
        
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer?.frame = self.webview.frame
    }
    
    private func setupCamera(completion: @escaping (Bool) -> Void) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        if let device = deviceDiscoverySession.devices.first {
            device.set(frameRate: 0.25, device: device)

            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                    setupPreview(captureSession, completion: completion)
                    return
                }
            }
        }
        completion(false)
    }
    
    private func setupPreview(_ captureSession: AVCaptureSession, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let previewLayer = AVCaptureVideoPreviewLayer(
                session: captureSession
            )
            DispatchQueue.main.async {
                self.previewLayer = previewLayer
                previewLayer.videoGravity = .resizeAspectFill
                self.view.layer.addSublayer(previewLayer)
                self.view.bringSubviewToFront(self.webview)
                self.view.bringSubviewToFront(self.headerView)
                previewLayer.frame = self.webview.frame
                
                self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
                
                self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera queue"))
                self.captureSession.addOutput(self.videoDataOutput)
                let videoConnection = self.videoDataOutput.connection(with: .video)
                videoConnection?.videoOrientation = .portrait
                completion(true)
            }
        }
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
        guard !observations.isEmpty, let previewLayer else {
            movingTracked.append(false)
            return
        }
        for observation in observations {
            let faceRectConverted = previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
//            let faceRectanglePath = CGPath(rect: faceRectConverted, transform: nil)
            
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
//        let landmarkPath = CGMutablePath()
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

extension LiveFeedViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        defer {
            textField.resignFirstResponder()
            view.endEditing(true)
        }
        
        var urlString = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !urlString.isEmpty else { return true }
        if let url = URL(string: textField.text ?? "") {
            if url.scheme == nil {
                urlString = "https://" + urlString
            }
            if url.pathExtension.isEmpty {
                urlString += ".com"
            }
            if let newURL = URL(string: urlString) {
                let request = URLRequest(url: newURL)
                webview.load(request)
            }
        } else if let url = URL(string: "https://\(textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")") {
            let request = URLRequest(url: url)
            webview.load(request)
        } else {
            textField.text = ""
        }
        return true
    }
}
