//
//  ViewController.swift
//  NearbyMessages
//
//  Created by skamycki on 25/09/2017.
//  Copyright © 2017 skamycki. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private var gnsManager :GNSMessageManager?
    private var subscribtion : GNSSubscription?
    private var nearbyPublication : GNSPublication?
    
    private let publishingString : String = "Publishing"
    private let notPublishingString = "Not publishing"
    private let subscribedString = "Subscribed"
    private let notSubscribedString = "Not subscribed"
    
    @IBOutlet private weak var publishLabel: UILabel!
    @IBOutlet private weak var publishIcon: UIButton!
    
    @IBOutlet private weak var subscribeLabel: UILabel!
    @IBOutlet private weak var subscribeButton: UIButton!
    
    @IBOutlet private weak var earshotSwitch: UISwitch!
    @IBOutlet private weak var beaconsSwitch: UISwitch!
    
    @IBOutlet private weak var messageTextField: UITextField!
    @IBOutlet private weak var logTextView: UITextView!
    
    private var earshotDistance = false
    private var includeBeacons = false
    private var isPublishing = false {
        didSet {
            if(isPublishing) {
                publishLabel.text = publishingString
                publishIcon.setImage(#imageLiteral(resourceName: "ic_stop"), for: .normal)
            } else {
                publishLabel.text = notPublishingString
                publishIcon.setImage(#imageLiteral(resourceName: "ic_start"), for: .normal)
            }
        }
    }
    private var isSubscribed = false {
        didSet {
            switchState(isSubscribed)
            if(isSubscribed) {
                subscribeLabel.text = subscribedString
                subscribeButton.setImage(#imageLiteral(resourceName: "ic_stop"), for: .normal)
            } else {
                subscribeLabel.text = notSubscribedString
                subscribeButton.setImage(#imageLiteral(resourceName: "ic_start"), for: .normal)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.messageTextField.delegate = self
        messageTextField.text = UIDevice.current.name
    }
    
    override func viewDidAppear(_ animated: Bool) {
        gnsManager = loadGNSMessageManager();
        let nearbyPermission = GNSPermission.isGranted()
        updateLog("Permission state \(nearbyPermission)")
        
        if gnsManager != nil {
            let nearbyPermission = GNSPermission(changedHandler: { (granted: Bool) in
                self.updateLog("Permission: \(granted)")
            })
        } else {
            let alert = UIAlertController.init(title: "Nearby Messages", message: "API key is not set", preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "OK", style: .default, handler: { (_) in
                exit(0)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction private func onPublishButtonClicked(_ sender: UIButton) {
        if isPublishing {
            nearbyPublication = nil
            updateLog("Unpublishing")
            return
        }
        
        guard let gnsManager = gnsManager else {
            updateLog("Error while publishing")
            return
        }
        
        let message = GNSMessage(content: messageTextField.text!.data(using: .utf8))
        nearbyPublication = gnsManager.publication(with: message,
                                                   paramsBlock: { (params: GNSPublicationParams?) in
                                                    guard let message = message else { return }
                                                    guard let params = params else { return }
                                                    
                                                    self.updateLog("Publishing message: \(String.utf8encoded(data: message.content)!)")
                                                    
                                                    params.permissionRequestHandler = { (permissionHandler: GNSPermissionHandler?) in
                                                        self.updateLog("Microphone permission error")
                                                    }
                                                    
                                                    params.statusHandler = { (status: GNSOperationStatus) in
                                                        self.isPublishing = status.rawValue == GNSOperationStatus.active.rawValue
                                                    }
                                                    
                                                    params.strategy = GNSStrategy(paramsBlock: { (strategyParams) in
                                                        strategyParams?.discoveryMediums = self.earshotDistance ? .audio : .BLE
                                                    })
        })
    }
    
    @IBAction private func onSubscribeButtonClicked(_ sender: UIButton) {
        if isSubscribed {
            subscribtion = nil
            updateLog("Unsubscribing")
            return
        }
        
        guard let gnsManager = gnsManager else {
            self.updateLog("Error while subscribing")
            return
        }
        
        subscribtion = gnsManager.subscription(messageFoundHandler: { (message: GNSMessage?) in
            if let message = message, !message.content.isEmpty {
                self.updateLog("Message found: \(String.utf8encoded(data: message.content)!) \(message.messageNamespace!) \(message.type!)")
            }
        },messageLostHandler: { (message: GNSMessage?) in
            guard let message = message else { return }
            
            self.updateLog("Message lost: \(String.utf8encoded(data: message.content)!)")
        }, paramsBlock: {(params: GNSSubscriptionParams?) in
            guard let params = params else { return }
            
            params.statusHandler = {(status: GNSOperationStatus) in
                self.isSubscribed = status.rawValue == GNSOperationStatus.active.rawValue
            }
            
            if self.includeBeacons {
                params.deviceTypesToDiscover = .bleBeacon
//                params.type = ""
//                params.messageNamespace = ""
                
                params.beaconStrategy = GNSBeaconStrategy(paramsBlock: { (strategyParam) in
                    strategyParam?.includeIBeacons = true
                    strategyParam?.lowPowerPreferred = false
                })
            }
        })
    }
    
    @IBAction private func earshotValueChanged(_ sender: UISwitch) {
        includeBeacons = sender.isOn
    }
    
    @IBAction private func includeBeaconsValueChanged(_ sender: UISwitch) {
        if sender.isOn {
            includeBeacons = true
        }
    }
    
    private func loadGNSMessageManager() -> GNSMessageManager? {
        if let path = Bundle.main.path(forResource: "secret", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                GNSMessageManager.setDebugLoggingEnabled(true)
                return GNSMessageManager(
                    apiKey: dict["API_KEY"],
                    paramsBlock: { (params: GNSMessageManagerParams?) in
                        guard let params = params else { return }
                        params.microphonePermissionErrorHandler = { (hasError: Bool) in
                            self.updateLog("Microphone permission error")
                        }
                        params.bluetoothPowerErrorHandler = { (hasError: Bool) in
                            self.updateLog("Bluetooth power error")
                        }
                        params.bluetoothPermissionErrorHandler = { (hasError: Bool) in
                            self.updateLog("Bluetooth permission error")
                        }
                        params.shouldShowBluetoothPowerAlert = true
                })
            }
        }
        return nil
    }
    
    private func switchState(_ isSubscribed : Bool) {
        if isSubscribed {
            beaconsSwitch.isEnabled = false
            earshotSwitch.isEnabled = false
        } else {
            beaconsSwitch.isEnabled = true
            earshotSwitch.isEnabled = true
        }
    }
    
    private func updateLog(_ log : String) {
        logTextView.text.append(log + "\n")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

//MARK:- extension: UITextFieldDelegate
extension ViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
}
