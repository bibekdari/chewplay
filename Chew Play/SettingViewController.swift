//
//  SettingViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 31/01/2024.
//

import UIKit
import ARKit

class Store {
    private enum Constants {
        enum Keys {
            static let chewTimesKey = "chew_time"
            static let resetTimeIntervalKey = "reset_time"
            static let rewardTimeKey = "reward_time"
            static let sensitivity = "sensitivity"
        }
        
        static let defaultNoOfChews = 3
        static let minNoOfChews = 1
        
        static let defaultSensitivity: Float = 6
        
        static let defaultResetTimeInterval = 5
        static let minResetTimeInterval = 1
        static let maxResetTimeInterval = 30
        
        static let defaultRewardTime = 30
        static let maxRewardTime = 45
        static let minRewardTime = 5
    }
    
    let observationTimeInterval: Double = 0.25
    
    private(set) var sensitivity: Float {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: Constants.Keys.sensitivity)
        }
    }

    private(set) var noOfChews: Int {
        didSet {
            UserDefaults.standard.set(noOfChews, forKey: Constants.Keys.chewTimesKey)
        }
    }
    
    private(set) var resetTimeInterval: Int {
        didSet {
            UserDefaults.standard.set(resetTimeInterval, forKey: Constants.Keys.resetTimeIntervalKey)
        }
    }
    
    private(set) var rewardTime: Int {
        didSet {
            UserDefaults.standard.set(rewardTime, forKey: Constants.Keys.rewardTimeKey)
        }
    }
    
    private var maxChews: Double {
        Double(resetTimeInterval) / observationTimeInterval
    }
    
    init() {
        self.noOfChews = (UserDefaults.standard.value(forKey: Constants.Keys.chewTimesKey) as? Int) ?? Constants.defaultNoOfChews
        
        self.resetTimeInterval = (UserDefaults.standard.value(forKey: Constants.Keys.resetTimeIntervalKey) as? Int) ?? Constants.defaultResetTimeInterval
        
        self.rewardTime = (UserDefaults.standard.value(forKey: Constants.Keys.rewardTimeKey) as? Int) ?? Constants.defaultRewardTime
        
        self.sensitivity = (UserDefaults.standard.value(forKey: Constants.Keys.sensitivity) as? Float) ?? Constants.defaultSensitivity
    }
    
    func increment(by value: Int) {
        let newValue = noOfChews + value
        if newValue < Constants.minNoOfChews || newValue > Int(maxChews) {
            return
        }
        noOfChews = newValue
    }
    
    func incrementTime(by value: Int) {
        let newValue = resetTimeInterval + value
        if newValue < Constants.minResetTimeInterval || newValue > Constants.maxResetTimeInterval {
            return
        }
        resetTimeInterval = newValue
        
        if noOfChews > Int(maxChews) {
            noOfChews = Int(maxChews)
        }
    }
    
    func incrementReward(by value: Int) {
        let newValue = rewardTime + value
        if newValue < Constants.minRewardTime || newValue > Constants.maxRewardTime {
            return
        }
        rewardTime = newValue
    }
    
    func changeSensitivity(to value: Float) {
        sensitivity = value
    }
    
    func reset() {
        self.noOfChews = Constants.defaultNoOfChews
        self.resetTimeInterval = Constants.defaultResetTimeInterval
        self.rewardTime = Constants.defaultRewardTime
    }
}

class SettingViewController: UIViewController {
    let store = Store()
    
    @IBOutlet public var sensitivitySlider: UISlider! {
        didSet {
            updateValue()
        }
    }
    
    @IBOutlet public var countLabel: UILabel! {
        didSet {
            updateValue()
        }
    }
    
    @IBOutlet public var timeIntervalLabel: UILabel! {
        didSet {
            updateValue()
        }
    }
    
    @IBOutlet public var rewardLabel: UILabel! {
        didSet {
            updateValue()
        }
    }
    
    @IBOutlet public var textLabel: UILabel! {
        didSet {
            updateValue()
        }
    }
    
    private func updateValue() {
        countLabel?.text = "\(store.noOfChews) times"
        timeIntervalLabel?.text = "per \(store.resetTimeInterval) sec"
        rewardLabel?.text = "\(store.rewardTime) sec reward"
        textLabel?.text = "\(store.noOfChews) chews/ \(store.resetTimeInterval) sec for \(store.rewardTime) sec of reward"
        sensitivitySlider?.setValue(store.sensitivity, animated: true)
    }
    
    @IBAction public func plus(_ sender: UIButton) {
        store.increment(by: 1)
        updateValue()
    }
    
    @IBAction public func minus(_ sender: UIButton) {
        store.increment(by: -1)
        updateValue()
    }
    
    @IBAction public func plusTime(_ sender: UIButton) {
        store.incrementTime(by: 1)
        updateValue()
    }
    
    @IBAction public func minusTime(_ sender: UIButton) {
        store.incrementTime(by: -1)
        updateValue()
    }
    
    @IBAction public func plusReward(_ sender: UIButton) {
        store.incrementReward(by: 1)
        updateValue()
    }
    
    @IBAction public func minusReward(_ sender: UIButton) {
        store.incrementReward(by: -1)
        updateValue()
    }
    
    @IBAction public func sensitivityChange(_ sender: UISlider) {
        store.changeSensitivity(to: sender.value)
        updateValue()
    }
    
    @IBAction public func reset(_ sender: UIButton) {
        store.reset()
        updateValue()
    }
    
    @IBAction public func start(_ sender: UIButton) {
        if ARFaceTrackingConfiguration.isSupported {
            let vc = ARLiveFeedViewController()
            self.present(vc, animated: true)
        }else {
            let vc = LiveFeedViewController()
            self.present(vc, animated: true)
        }
    }
}
