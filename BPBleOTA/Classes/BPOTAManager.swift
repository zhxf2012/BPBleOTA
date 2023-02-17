//
//  BPOTAManager.swift
//  BPenOTASDK
//
//  Created by xingfa on 2023/2/15.
//

import Foundation
import CoreBluetooth
#if TARGET_IPHONE_SIMULATOR

#else
import iOSMcuManagerLibrary
import iOSDFULibrary
#endif

let ErrorDomain = "BPOTAMangerDomain"

public class BPOTAManager:NSObject {
    
   @objc public enum DFUProtocolType: Int {
        case NordicDFU
        case SMPDFU
    }
    
    fileprivate var otaProgress:((Int,String) ->Void)?
    fileprivate var completedHandel:((Bool,Error?) -> Void)?
    
#if TARGET_IPHONE_SIMULATOR
    
#else
    
    fileprivate  lazy var proxy: BPOTAManagerProxy = {
         let item = BPOTAManagerProxy.init(manager: self)
         return item
     }()
    
    var dfuManager: FirmwareUpgradeManager?
    var dfuController: DFUServiceController?
    
    private func classicOTAWithPeripheral(_ peripheral:CBPeripheral,file:String) {
        do {
            let path =  URL(fileURLWithPath: file)
            let firmware = try DFUFirmware.init(urlToZipFile: path)
            let initiator = DFUServiceInitiator.init().with(firmware: firmware)
            initiator.delegate = self.proxy
            initiator.progressDelegate = self.proxy
            initiator.logger = self.proxy
            guard let controller =  initiator.start(target: peripheral) else {
                completedHandel?(false,NSError.init(domain: ErrorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey:"未能开启DFU"]))
                return
            }
            self.dfuController = controller
        } catch  {
            completedHandel?(false,error);
        }
    }
    
    private func spmOTAWithPeripheral(_ peripheral:CBPeripheral,file:String) {
        do {
            let path =  URL(fileURLWithPath: file)
            let package = try McuMgrPackage(from: path)
            let dfuManagerConfiguration = FirmwareUpgradeConfiguration(
                estimatedSwapTime: 10.0, eraseAppSettings: true, pipelineDepth: 3, byteAlignment: .fourByte)
            let bleTransporter = McuMgrBleTransport(peripheral)
            bleTransporter.logDelegate = self.proxy
            bleTransporter.delegate = self.proxy
            let manager  = FirmwareUpgradeManager(transporter: bleTransporter, delegate: self.proxy)
            manager.mode = .testAndConfirm
           
            self.dfuManager = manager
            try manager.start(images: package.images,using: dfuManagerConfiguration)
            
        } catch  {
            completedHandel?(false,error);
        }
    }
#endif
    
    
    @objc public func otaWithPeripheral(_ peripheral:CBPeripheral,dfuProtocol:DFUProtocolType,firmareFilePath:String,otaProgress:@escaping ((Int,String) ->Void),completedHandel:@escaping ((Bool,Error?) -> Void)) {
#if TARGET_IPHONE_SIMULATOR
        completedHandel(false,NSError.init(domain: ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"模拟器上不支持OTA升级"]))
#else
        
        guard FileManager.default.fileExists(atPath: firmareFilePath) else {
            completedHandel(false,NSError.init(domain: ErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey:"未找到有效的固件文件:\(firmareFilePath)"]))
            return
        }
    
        self.otaProgress = otaProgress
        self.completedHandel = completedHandel
        
        switch dfuProtocol {
        case .NordicDFU:
            classicOTAWithPeripheral(peripheral, file: firmareFilePath)
        case .SMPDFU:
            spmOTAWithPeripheral(peripheral, file: firmareFilePath)
        }
#endif
    }
    
    
}


#if TARGET_IPHONE_SIMULATOR
#else
fileprivate class BPOTAManagerProxy: NSObject {
    unowned let manager: BPOTAManager
    
    required init(manager: BPOTAManager) {
        self.manager = manager
        super.init()
    }
}

extension BPOTAManagerProxy: DFUServiceDelegate,DFUProgressDelegate,LoggerDelegate {
    public func dfuStateDidChange(to state: DFUState) {
        debugPrint("升级状态：\(state),\(state.description)")
        if state == .completed {
            self.manager.completedHandel?(true,nil)
            self.manager.dfuController = nil
            self.manager.completedHandel = nil
            self.manager.otaProgress = nil
        }
    }
    
    public func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
         debugPrint(error,message)
        self.manager.completedHandel?(false,NSError.init(domain: ErrorDomain, code: error.rawValue, userInfo: [NSLocalizedDescriptionKey : message]))
    }
    
    public func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
         let currentProgress = Float(progress) / Float(totalParts)
        let percent = Int(currentProgress)
        let msg = "升级进度 part:\(part),totoalParts:\(totalParts),progress:\(progress)   percent:\(percent)%"
        self.manager.otaProgress?(percent,msg)
    }
    
    public func logWith(_ level: LogLevel, message: String) {
        debugPrint("升级日志(\(level.name()):",message)
    }

}

extension BPOTAManagerProxy: McuMgrLogDelegate,PeripheralDelegate,FirmwareUpgradeDelegate {
    public func upgradeDidStart(controller: FirmwareUpgradeController) {
        
    }
    
    public func upgradeStateDidChange(from previousState: FirmwareUpgradeState, to newState: FirmwareUpgradeState) {
        
    }
    
    public func upgradeDidComplete() {
        
    }
    
    public func upgradeDidFail(inState state: FirmwareUpgradeState, with error: Error) {
        
    }
    
    public func upgradeDidCancel(state: FirmwareUpgradeState) {
        
    }
    
    public func uploadProgressDidChange(bytesSent: Int, imageSize: Int, timestamp: Date) {
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didChangeStateTo state: PeripheralState) {
         
    }
    
    public func log(_ msg: String, ofCategory category: McuMgrLogCategory, atLevel level: McuMgrLogLevel) {
         
    }
}


#endif
