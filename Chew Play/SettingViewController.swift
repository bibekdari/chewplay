//
//  SettingViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 31/01/2024.
//

import UIKit

class Store {
    private enum Constants {
        static let chewTimesKey = "chew_time"
        static let resetTimeIntervalKey = "reset_time"
        static let defaultNoOfChews = 3
        static let minNoOfChews = 1
        static let defaultResetTimeInterval = 5.0
        static let minResetTimeInterval = 1.0
        static let maxResetTimeInterval = 30.0
    }

    private(set) var noOfChews: Int {
        didSet {
            UserDefaults.standard.set(noOfChews, forKey: Constants.chewTimesKey)
        }
    }
    
    private(set) var resetTimeInterval: Double {
        didSet {
            UserDefaults.standard.set(resetTimeInterval, forKey: Constants.resetTimeIntervalKey)
        }
    }
    let observationTimeInterval: Double = 0.25
    
    private var maxChews: Double {
        resetTimeInterval / observationTimeInterval
    }
    
    init() {
        self.noOfChews = (UserDefaults.standard.value(forKey: Constants.chewTimesKey) as? Int) ?? Constants.defaultNoOfChews
        self.resetTimeInterval = (UserDefaults.standard.value(forKey: Constants.resetTimeIntervalKey) as? Double) ?? Constants.defaultResetTimeInterval
    }
    
    func increment(by value: Int) {
        let newValue = noOfChews + value
        if newValue < Constants.minNoOfChews || newValue > Int(maxChews) {
            return
        }
        noOfChews = newValue
    }
    
    func incrementTime(by value: Int) {
        let newValue = resetTimeInterval + Double(value)
        if newValue < Constants.minResetTimeInterval || newValue > Constants.maxResetTimeInterval {
            return
        }
        resetTimeInterval = newValue
        
        if noOfChews > Int(maxChews) {
            noOfChews = Int(maxChews)
        }
    }
    
    func reset() {
        self.noOfChews = Constants.defaultNoOfChews
        self.resetTimeInterval = Constants.defaultResetTimeInterval
    }
}

class SettingViewController: UIViewController {
    let store = Store()
    
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
    
    @IBOutlet public var textLabel: UILabel! {
        didSet {
            updateValue()
        }
    }
    
    private func updateValue() {
        countLabel?.text = "\(store.noOfChews) times"
        timeIntervalLabel?.text = "per \(Int(store.resetTimeInterval)) sec"
        textLabel?.text = "\(store.noOfChews) chews per \(Int(store.resetTimeInterval)) sec"
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
    
    @IBAction public func reset(_ sender: UIButton) {
        store.reset()
        updateValue()
    }
}
