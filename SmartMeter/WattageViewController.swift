//
//  ViewController.swift
//  SmartMeter
//
//  Created by Remus Lazar on 15.06.15.
//  Copyright (c) 2015 Remus Lazar. All rights reserved.
//

import UIKit

struct UserDefaults {
    static let SmartmeterHostname = "smartmeter_hostname"
    static let SmartmeterRefreshRate = "smartmeter_refresh_rate"
}

private struct Storyboard {
    static let ShowDeviceInfoSegueIdentifier = "ShowDeviceInfo"
    static let ShowHistorySegueIdentifier = "ShowHistory"
    static let GraphViewSegueIdentifier = "MiniGraph"
}

class WattageViewController: UIViewController, PowerMeterDelegate {
    
    private struct Labels {
        static let ActionSheetTitle = "Load Historical Data"
        static let ActionSheetMessage = "You can access up to about 8 hours of sampled data from the Power Meter"
    }
    
    private var autoUpdate = false {
        didSet {
            if autoUpdate {
                powerMeter?.startUpdatingCurrentWattage()
                pauseButton.title = "Pause"
                wattageLabel.hidden = false
            } else {
                powerMeter?.stopUpdatingCurrentWattage()
                pauseButton.title = "Resume"
                wattageLabel.hidden = true
            }
        }
    }
    
    // MARK: - Outlets
    @IBOutlet weak var wattageLabel: UILabel!
    @IBOutlet weak var statusBottomLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var pauseButton: UIBarButtonItem!
    
    @IBAction func toggleAutoupdate(sender: UIBarButtonItem) {
        autoUpdate = !autoUpdate
    }
    
    @IBAction func showActionsheet(sender: AnyObject) {
        let sheet = UIAlertController(
            title: Labels.ActionSheetTitle,
            message: Labels.ActionSheetMessage,
            preferredStyle: UIAlertControllerStyle.ActionSheet
        )
        if progressBar.hidden {
            for timespan in [5,15,30,60,120] {
                sheet.addAction(UIAlertAction(title: "\(timespan) minutes (\(timespan * 60) samples)",
                    style: .Default, handler: { (_) in
                        self.loadHistory(timespan: NSTimeInterval(timespan * 60))
                }))
            }
        } else {
            sheet.addAction(UIAlertAction(title: "Abort current transfer",
                style: .Destructive, handler: { (_) in
                    if !self.progressBar.hidden {
                        self.powerMeter?.abortCurrentFetchRequest = true
                    }
            }))
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        presentViewController(sheet, animated: true, completion: nil)
    }

    // load historical data from the power meter
    private func loadHistory(timespan: NSTimeInterval = 300) {
        self.progressBar.progress = 0
        self.progressBar.hidden = false
        let autoUpdateState = autoUpdate
        autoUpdate = false
        pauseButton.enabled = false
        powerMeter?.readSamples(Int(timespan), completionHandler: { (remaining) -> Void in
            self.progressBar.progress = Float(Int(timespan) - remaining) / Float(timespan)
            if (remaining <= 0) {
                self.progressBar.hidden = true
                self.autoUpdate = autoUpdateState
                self.pauseButton.enabled = true
            }
            self.updateUI()
        })
    }
    
    weak var graphVC: GraphViewController?
    
    // MARK: - Private data and methods
    private var powerMeter: PowerMeter?
    private var smartMeterHostname: String? {
        didSet {
            if smartMeterHostname != oldValue && smartMeterHostname != nil {
                powerMeter = PowerMeter(host: smartMeterHostname!)
                powerMeter?.delegate = self
                graphVC?.history = powerMeter?.history
            }
        }
    }
    
    private func updateUI() {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = NSDateFormatterStyle.NoStyle
        dateFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
        if let hist = powerMeter?.history where hist.startts != nil {
            statusBottomLabel.text = "\(hist.count) Samples, \(dateFormatter.stringFromDate(hist.startts!)) - \(dateFormatter.stringFromDate(hist.endts!))"
        } else {
            statusBottomLabel.text = nil
        }
        graphVC?.updateGraph()
    }
    
    func readUserDefaults() {
        println("(re)reading user defaults and init")
        if let hostname = NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) as? String {
            smartMeterHostname = hostname
        }
        if let updateInterval = NSUserDefaults().valueForKey(UserDefaults.SmartmeterRefreshRate) as? Double {
            powerMeter?.autoUpdateTimeInterval = NSTimeInterval(updateInterval)
        }
    }
    
    // MARK: - PowerMeterDelegate
    func didUpdateWattage(currentWattage: Int) {
        self.wattageLabel.text = "\(currentWattage) W"
        updateUI()
    }

    // MARK: - ViewController Lifetime
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        // popup the settings bundle if the settings are void
        if NSUserDefaults().valueForKey(UserDefaults.SmartmeterHostname) == nil {
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }
        
        autoUpdate = true
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        autoUpdate = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readUserDefaults()
        // listen for changes in the app settings and handle it
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("readUserDefaults"),
            name: NSUserDefaultsDidChangeNotification,
            object: nil)
        updateUI()
    }
   
    // MARK: - Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        switch (segue.identifier!) {

        case Storyboard.ShowDeviceInfoSegueIdentifier:
            if let powerMeterInfoTCC = segue.destinationViewController as? PowerMeterInfoTableViewController {
                powerMeterInfoTCC.powerMeter = self.powerMeter
            }

        case Storyboard.ShowHistorySegueIdentifier:
            if let historyTVC = segue.destinationViewController as? PowermeterHistoryTableViewController {
                historyTVC.history = powerMeter?.history
            }
            
        case Storyboard.GraphViewSegueIdentifier:
            if let vc = segue.destinationViewController as? GraphViewController {
                self.graphVC = vc
            }
            
        default: break
        }
    }

    // MARK: - deinit
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}
