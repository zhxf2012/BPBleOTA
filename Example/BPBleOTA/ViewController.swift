//
//  ViewController.swift
//  BPBleOTA
//
//  Created by zhouxingfa on 02/17/2023.
//  Copyright (c) 2023 zhouxingfa. All rights reserved.
//

import UIKit
import CoreBluetooth
import BPBleOTA

class ViewController: UIViewController {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var devicesView: UITableView!
    @IBOutlet weak var dfuProtocolSegment: UISegmentedControl!
    @IBOutlet weak var firmwareFileChooseButton: UIButton!
    @IBOutlet weak var firmwarePathLabel: UILabel!
    @IBOutlet weak var otaButton: UIButton!
    
    @IBOutlet weak var selectDeviceLabel: UILabel!
    private var centralManager: CBCentralManager = CBCentralManager()
    private var discoveredPeripherals = [DiscoveredPeripheral]()
    private let dfuManager = BPOTAManager.init()
    
    var selectPeripheral: DiscoveredPeripheral? {
        didSet {
            if let new = selectPeripheral {
                selectDeviceLabel.text = "已选择蓝牙外设：\(new.advertisedName)"
            } else {
                selectDeviceLabel.text = "未选择蓝牙外设"
            }
            
            adjustDFUAction()
        }
    }
    
    var firmwarePath: String? {
        didSet {
            if let new = firmwarePath {
                firmwarePathLabel.text = "已选择固件文件：\(new)"
            } else {
                firmwarePathLabel.text = "未选择固件文件"
            }
            
           adjustDFUAction()
        }
    }
    
    var isScanning = false {
        didSet {
            let title = isScanning ? "停止扫描蓝牙外设" : "开始扫描蓝牙外设"
            scanButton.setTitle(title, for: .normal)
            if isScanning {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }
    
    var currentDeiceDFUProtoclType: BPOTAManager.DFUProtocolType = .NordicDFU
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        centralManager.delegate = self
        dfuProtocolSegment.selectedSegmentIndex = 0
        adjustDFUAction()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        discoveredPeripherals.removeAll()
        devicesView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if centralManager.state == .poweredOn {
            activityIndicator.startAnimating()
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    func startOrStopScan() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        } else {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
            isScanning = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func adjustDFUAction() {
        let canOTA = canOTANow()
        self.otaButton.isEnabled =  canOTA
        self.dfuProtocolSegment.isEnabled = canOTA
    }
    
    func canOTANow() -> Bool{
        guard let _ = firmwarePath else {
            return false
        }
  
        guard let _ = selectPeripheral else {
            return false
        }
        
        return true

    }
    
    @IBAction func scanButtonTouched(_ sender: Any) {
        startOrStopScan()
    }
    
    @IBAction func firmwareFileChooseButtonTouched(_ sender: Any) {
        let importMenu = UIDocumentMenuViewController(documentTypes: ["public.data", "public.content"], in: .import)
        importMenu.delegate = self
        importMenu.popoverPresentationController?.sourceView = firmwareFileChooseButton
        present(importMenu, animated: true, completion: nil)
    }
    
    @IBAction func dfuProtocolSegmentValueChanged(_ sender: Any) {
        if  let mode = BPOTAManager.DFUProtocolType.init(rawValue: dfuProtocolSegment.selectedSegmentIndex) {
            currentDeiceDFUProtoclType = mode
        }
    }
    
    @IBAction func otaButtonTouched(_ sender: Any) {
        guard let selectPeripheral = selectPeripheral?.basePeripheral,let file = firmwarePath,FileManager.default.fileExists(atPath: file) else {
            fatalError("需要先选定外设和固件文件")
        }
        
        // 请确保蓝牙外设以及固件文件是指定的dfu协议
        
        otaButton.isEnabled = false
        dfuManager.otaWithPeripheral(selectPeripheral, dfuProtocol: currentDeiceDFUProtoclType, firmareFilePath: file) { progress, msg in
            self.showProgressWith("\(progress)%", progressMsg: msg)
        } completedHandel: {[weak self] result, error in
            self?.adjustDFUAction()
            if let error = error {
                self?.showMessageWithTitle(msg: "OTA失败:\(error.localizedDescription)")
            } else {
                self?.showMessageWithTitle(msg: "OTA成功")
            }
        }
    }
}

extension ViewController:CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Find peripheral among already discovered ones, or create a new
        // object if it is a new one.
        guard  let  discoveredPeripheralIndex = discoveredPeripherals.firstIndex(where: { $0.basePeripheral.identifier == peripheral.identifier }) else {
         
            let discoveredPeripheral = DiscoveredPeripheral(peripheral)
            _ =  discoveredPeripheral.update(withAdvertisementData: advertisementData, andRSSI: RSSI)
            discoveredPeripherals.append(discoveredPeripheral)
            devicesView.reloadSections(.init(integer: 0), with: .automatic)
            return
        }
            
            let discoveredPeripheral = discoveredPeripherals[discoveredPeripheralIndex]
            // Update the object with new values.
        if discoveredPeripheral.update(withAdvertisementData: advertisementData, andRSSI: RSSI) {
            devicesView.reloadRows(at: [IndexPath.init(row: discoveredPeripheralIndex, section: 0)], with: .automatic)
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            print("Central is not powered on")
            isScanning = false
        } else {
            startOrStopScan()
        }
    }
}

extension ViewController:UITableViewDelegate,UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredPeripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let aCell = tableView.dequeueReusableCell(withIdentifier: ScannerTableViewCell.reuseIdentifier, for: indexPath) as! ScannerTableViewCell
        aCell.setupViewWithPeripheral(discoveredPeripherals[indexPath.row])
        return aCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if isScanning {
            startOrStopScan()
        }
        selectPeripheral = discoveredPeripherals[indexPath.row]
    }
}


// MARK: - Document Picker
extension ViewController: UIDocumentMenuDelegate, UIDocumentPickerDelegate {
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController,
                      didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentAt url: URL) {
        firmwarePath = url.path
    }

}
