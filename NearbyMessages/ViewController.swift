//
//  ViewController.swift
//  NearbyMessages
//
//  Created by skamycki on 25/09/2017.
//  Copyright © 2017 skamycki. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var gnsManager :GNSMessageManager?
    var subscribtion : GNSSubscription?
    var nearbyPublication : GNSPublication?
    
    private let publishingString : String = "Publishing"
    private let notPublishingString = "Not publishing"
    private let subscribedString = "Subscribed"
    private let notSubscribedString = "Not subscribed"
    
    @IBOutlet weak var publishLabel: UILabel!
    @IBOutlet weak var publishIcon: UIButton!
    
    @IBOutlet weak var subscribeLabel: UILabel!
    @IBOutlet weak var subscribeButton: UIButton!
    
    @IBOutlet weak var earshotSwitch: UISwitch!
    @IBOutlet weak var beaconsSwitch: UISwitch!
    
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var logTextView: UITextView!
    
    var isPublishing = false {
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
    
    var isSubscribed = false {
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
    
    var earshotDistance = false
    
    var includeBeacons = false
    
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
                self.updateLog("Permission \(granted)")
            })
        } else {
            let alert = UIAlertController.init(title: "Nearby Messages", message: "API key is not set", preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "OK", style: .default, handler: { (_) in
                exit(0)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func onPublishButtonClicked(_ sender: UIButton) {
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
    
    @IBAction func onSubscribeButtonClicked(_ sender: UIButton) {
        guard let gnsManager = gnsManager else {
            self.updateLog("Error while subscribing")
            return
        }
        
        subscribtion = gnsManager.subscription(messageFoundHandler: { (message: GNSMessage?) in
            
            if let message = message, !message.content.isEmpty {
                self.updateLog("Message found: \(String.utf8encoded(data: message.content)!) \(message.messageNamespace!) \(message.type!)")
            }
        }, messageLostHandler: { (message: GNSMessage?) in
            guard let message = message else { return }
            
            self.updateLog("Message lost: \(String.utf8encoded(data: message.content)!)")
        }, paramsBlock: {(params: GNSSubscriptionParams?) in
            guard let params = params else { return }
            
            params.statusHandler = {(status: GNSOperationStatus) in
                self.isSubscribed = status.rawValue == GNSOperationStatus.active.rawValue
            }
            
            if self.includeBeacons {
                params.deviceTypesToDiscover = .bleBeacon
                params.beaconStrategy = GNSBeaconStrategy(paramsBlock: { (strategyParam) in
                    strategyParam?.includeIBeacons = true
                    strategyParam?.lowPowerPreferred = true
                })
            }
        })
        
    }
    
    @IBAction func earshotValueChanged(_ sender: UISwitch) {
        includeBeacons = sender.isOn
    }
    
    
    @IBAction func includeBeaconsValueChanged(_ sender: UISwitch) {
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
