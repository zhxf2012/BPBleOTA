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
    
    @objc public enum BPDFUError: Int {
         case  unknow
         case  simlatorDoesNotSupportDFU
         case  invalidFirmwareFile
         case  startDFUFailed
         case  dfuCancel
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
                completedHandel?(false,NSError.init(domain: ErrorDomain, code: BPDFUError.startDFUFailed.rawValue, userInfo: [NSLocalizedDescriptionKey:"未能开启DFU"]))
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
            manager.mode = .confirmOnly
           
            self.dfuManager = manager
            try manager.start(images: package.images,using: dfuManagerConfiguration)
            
        } catch  {
            completedHandel?(false,error);
        }
    }
#endif
    
    
    @objc public func otaWithPeripheral(_ peripheral:CBPeripheral,dfuProtocol:DFUProtocolType,firmareFilePath:String,otaProgress:@escaping ((Int,String) ->Void),completedHandel:@escaping ((Bool,Error?) -> Void)) {
#if TARGET_IPHONE_SIMULATOR
        completedHandel(false,NSError.init(domain: ErrorDomain, code: BPDFUError.simlatorDoesNotSupportDFU, userInfo: [NSLocalizedDescriptionKey:"模拟器上不支持OTA升级"]))
#else
        
        guard FileManager.default.fileExists(atPath: firmareFilePath) else {
            completedHandel(false,NSError.init(domain: ErrorDomain, code: BPDFUError.invalidFirmwareFile.rawValue, userInfo: [NSLocalizedDescriptionKey:"未找到有效的固件文件:\(firmareFilePath)"]))
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
        debugPrint(#function,"from:\(previousState) to \(newState)")
        switch newState {
        case .none:
            break
        case .requestMcuMgrParameters:
            debugPrint("REQUESTING MCUMGR PARAMETERS...")
        case .validate:
            debugPrint("VALIDATING...")
        case .upload:
            debugPrint( "UPLOADING...")
       // case .eraseAppSettings:
            //debugPrint("ERASING APP SETTINGS...")
        case .test:
            debugPrint("TESTING...")
        case .confirm:
            debugPrint("CONFIRMING...")
        case .reset:
            debugPrint("RESETTING...")
        case .success:
            debugPrint("UPLOAD COMPLETE")
        }
    }
    
    public func upgradeDidComplete() {
        debugPrint(#function)
        self.manager.completedHandel?(true,nil)
        self.manager.dfuController = nil
        self.manager.completedHandel = nil
        self.manager.otaProgress = nil
    }
    
    public func upgradeDidFail(inState state: FirmwareUpgradeState, with error: Error) {
        debugPrint(#function,state,error)
        self.manager.completedHandel?(false,error)
    }
    
    public func upgradeDidCancel(state: FirmwareUpgradeState) {
        
        self.manager.completedHandel?(false,NSError.init(domain: ErrorDomain, code: BPOTAManager.BPDFUError.dfuCancel.rawValue, userInfo: [NSLocalizedDescriptionKey : "取消升级，当前步骤：\(state)"]))
    }
    
    public func uploadProgressDidChange(bytesSent: Int, imageSize: Int, timestamp: Date) {
        let currentProgress = Float(bytesSent) / Float(imageSize)
        let percent = Int(currentProgress * 100)
        let msg = "升级进度 已发送:\(bytesSent),总大小:\(imageSize),progress:\(currentProgress)   percent:\(percent)% -- \(timestamp)"
        self.manager.otaProgress?(percent,msg)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didChangeStateTo state: PeripheralState) {
         
    }
    
    public func log(_ msg: String, ofCategory category: McuMgrLogCategory, atLevel level: McuMgrLogLevel) {
         
    }
}


#endif
