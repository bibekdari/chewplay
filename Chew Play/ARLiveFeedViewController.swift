//
//  LiveFeedViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 28/01/2024.
//

import UIKit
import ARKit
import WebKit

class ARLiveFeedViewController: UIViewController {
    private let store = Store()
    private let session = ARSession()
    
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
    private let indicator = UIImageView(image: .init(systemName: "globe")?.withAlignmentRectInsets(.init(top: -8, left: -8, bottom: -8, right: -8)))
    private let webview = WKWebView()
    private var timer: Timer?
    private var check = true
    private var time: Double = 0 {
        didSet {
            if time >= Double(store.resetTimeInterval) {
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
                
                let reward = max((store.rewardTime - store.resetTimeInterval), store.resetTimeInterval)
                
                DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(reward))) { [weak self] in
                    self?.setTimer()
                }
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
        session.delegate = self
        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        textField.delegate = self
        
        view.addSubview(headerView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 40),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        
        headerView.addArrangedSubview(indicator)
        headerView.addArrangedSubview(textField)
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(.init(systemName: "xmark"), for: .normal)
        button.addAction(UIAction(handler: { [weak self] _ in
            self?.dismiss(animated: true)
        }), for: .touchUpInside)
        headerView.addArrangedSubview(button)
        
        NSLayoutConstraint.activate([
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
        
        isChewing = true
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

extension ARLiveFeedViewController: ARSessionDelegate {
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

extension ARLiveFeedViewController: UITextFieldDelegate {
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
