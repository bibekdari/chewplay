//
//  LiveFeedViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 28/01/2024.
//

import UIKit
import WebKit
import Combine

class LiveFeedViewController: UIViewController {
    private let captureManager: CaptureManager
    private var mediaPlaybackSuspended = false
    var store: Store {
        captureManager.store
    }
    
    var previewLayer: CALayer? {
        captureManager.previewLayer
    }
    
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
    private let indicator = UILabel()
    private let webview = WKWebView()
    private let timeLabel = UILabel()
    
    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        textField.delegate = self
        timeLabel.textAlignment = .center
        
        let refreshButton = UIButton()
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.setImage(.init(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.addAction(UIAction(handler: { [weak self] _ in
            self?.webview.reload()
        }), for: .touchUpInside)
        
        view.addSubview(headerView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 40),
            headerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        headerView.addArrangedSubview(timeLabel)
        headerView.addArrangedSubview(indicator)
        headerView.addArrangedSubview(refreshButton)
        headerView.addArrangedSubview(textField)
        
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(.init(systemName: "xmark"), for: .normal)
        button.addAction(UIAction(handler: { [weak self] _ in
            self?.dismiss(animated: true)
        }), for: .touchUpInside)
        headerView.addArrangedSubview(button)
        
        NSLayoutConstraint.activate([
            timeLabel.widthAnchor.constraint(equalTo: timeLabel.heightAnchor),
            indicator.widthAnchor.constraint(equalTo: indicator.heightAnchor),
            button.widthAnchor.constraint(equalTo: button.heightAnchor),
            refreshButton.widthAnchor.constraint(equalTo: refreshButton.heightAnchor)
        ])

        webview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webview)
        NSLayoutConstraint.activate([
            webview.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            webview.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webview.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        webview.configuration.allowsPictureInPictureMediaPlayback = false
        let request = URLRequest(url: URL(string: "https://www.youtube.com/")!)
        webview.load(request)
        
        captureManager.progress
            .sink { [weak self] value in
                self?.timeLabel.text = "\(value)s"
            }.store(in: &cancellables)
        
        captureManager.setOnSetPreviewLayer { [weak self] previewLayer in
            guard let self else { return }
            self.view.layer.addSublayer(previewLayer)
            self.view.bringSubviewToFront(self.webview)
            self.view.bringSubviewToFront(self.headerView)
            previewLayer.frame = self.webview.frame
        }
        
        captureManager.setup()
        captureManager.isChewing
            .sink {[weak self] in
                guard let self else { return }
                if $0 {
                    self.indicator.text = "🟢"
                    if self.mediaPlaybackSuspended {
                        self.mediaPlaybackSuspended = false
                        self.webview.setAllMediaPlaybackSuspended(false)
                    }
                } else {
                    self.indicator.text = "🔴"
                    if !self.mediaPlaybackSuspended {
                        self.mediaPlaybackSuspended = true
                        self.webview.setAllMediaPlaybackSuspended(true)
                    }
                }
            }
            .store(in: &cancellables)
        captureManager.setup()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer?.frame = self.webview.frame
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
