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
    var isPublishing = false {
        didSet {
            if(isPublishing) {
                publishLabel.text = "Publishing"
                publishIcon.setImage(UIImage(named: "ic_stop"), for: .normal)
            } else {
                publishLabel.text = "Not publishing"
                publishIcon.setImage(UIImage(named: "ic_start"), for: .normal)
            }
        }
    }
    var isSubscribed = false {
        didSet {
            if(isSubscribed) {
                subscribeLabel.text = "Subscribed"
                subscribeButton.setImage(UIImage(named: "ic_stop"), for: .normal)
            } else {
                subscribeLabel.text = "No subscribed"
                subscribeButton.setImage(UIImage(named: "ic_start"), for: .normal)
            }
        }
    }
    
    var earshotDistance = false {
        didSet {
        }
    }
    
    var includeBeacons = false
    
    @IBOutlet weak var publishLabel: UILabel!
    @IBOutlet weak var publishIcon: UIButton!
    
    @IBOutlet weak var subscribeLabel: UILabel!
    @IBOutlet weak var subscribeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        gnsManager = loadGNSMessageManager();
        let nearbyPermission = GNSPermission.isGranted()
        print("Permission state \(nearbyPermission)")
        if gnsManager != nil {
            let nearbyPermission = GNSPermission(changedHandler: { (granted: Bool) in
                print("Permission \(granted)")
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
            print("Error while publishing")
            return
        }
        //TODO get device name as default
        let message = GNSMessage(content: "name".data(using: .utf8))
        nearbyPublication = gnsManager.publication(with: message,
                                                   paramsBlock: { (params: GNSPublicationParams?) in
                                                    guard let params = params else {
                                                        return
                                                    }
                                                    params.permissionRequestHandler = { (permissionHandler: GNSPermissionHandler?) in
                                                        print("Microphone permission error")
                                                    }
                                                    params.statusHandler = { (status: GNSOperationStatus) in
                                                        self.isPublishing = status.rawValue == GNSOperationStatus.active.rawValue
                                                    }
                                                    
        })
    }
    @IBAction func onSubscribeButtonClicked(_ sender: UIButton) {
        guard let gnsManager = gnsManager else {
            print("Error while subscribig")
            return
        }
        subscribtion =
            gnsManager.subscription(messageFoundHandler: { (message: GNSMessage?) in
                guard let message = message else {return}
                let messageContent = String(data: message.content, encoding: .utf8)
                //TODO display raw string values
                print("Message found \(String(describing: messageContent)) \(message.messageNamespace) \(message.type)")
            },messageLostHandler: { (message: GNSMessage?) in
                //TODO which message was lost
                print("Message lost")
            }, paramsBlock: {(params: GNSSubscriptionParams?) in
                guard let params = params else {return}
                params.statusHandler = {(status: GNSOperationStatus) in
                    self.isSubscribed = status.rawValue == GNSOperationStatus.active.rawValue
                }
            })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func loadGNSMessageManager() -> GNSMessageManager? {
        if let path = Bundle.main.path(forResource: "secret", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                return GNSMessageManager(
                    apiKey: dict["API_KEY"],
                    paramsBlock: { (params: GNSMessageManagerParams?) in
                        guard let params = params else { return }
                        params.microphonePermissionErrorHandler = { (hasError: Bool) in
                            print("Microphone permission error")
                        }
                        params.bluetoothPowerErrorHandler = { (hasError: Bool) in
                            print("Bluetooth power error")
                        }
                        params.bluetoothPermissionErrorHandler = { (hasError: Bool) in
                            print("Bluetooth permission error")
                        }
                        params.shouldShowBluetoothPowerAlert = true
                })
            }
        }
        return nil
    }
}

