//
//  SettingViewController.swift
//  Chew Play
//
//  Created by bibek timalsina on 31/01/2024.
//

import UIKit

class Store {
    private let key = "chew_time"
    private(set) var noOfChews: Int
    
    let observationTimeInterval: Double = 0.25
    let resetTimeInterval: Double = 5
    private var maxChews: Double {
        resetTimeInterval / observationTimeInterval
    }
    
    init() {
        let noOfChews = UserDefaults.standard.integer(forKey: key)
        self.noOfChews = noOfChews < 1 ? 3 : noOfChews
    }
    
    func increment(by value: Int) {
        let newValue = noOfChews + value
        if newValue < 1 || newValue > Int(maxChews) {
            return
        }
        noOfChews = newValue
        UserDefaults.standard.set(newValue, forKey: key)
    }
}

class SettingViewController: UIViewController {
    let store = Store()
    
    @IBOutlet public var countLabel: UILabel! {
        didSet {
            updateValue()
        }
    }
    
    private func updateValue() {
        countLabel.text = "\(store.noOfChews)"
    }
    
    @IBAction public func plus(_ sender: UIButton) {
        store.increment(by: 1)
        updateValue()
    }
    
    @IBAction public func minus(_ sender: UIButton) {
        store.increment(by: -1)
        updateValue()
    }
}
