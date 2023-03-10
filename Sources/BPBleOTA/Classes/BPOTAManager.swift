//
//  BPOTAManager.swift
//  BPenOTASDK
//
//  Created by xingfa on 2023/2/15.
//

import Foundation
import CoreBluetooth
#if targetEnvironment(simulator)

#else

import iOSMcuManagerLibrary


#if SWIFT_PACKAGE
    import NordicDFU
#else
    import iOSDFULibrary
#endif


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
    
    fileprivate var otaDevice: CBPeripheral?
    fileprivate var firmwarePath:String = ""
    
#if targetEnvironment(simulator)
    
#else
    
    fileprivate  lazy var proxy: BPOTAManagerProxy = {
         let item = BPOTAManagerProxy.init(manager: self)
         return item
     }()
    
    fileprivate  var dfuManager: FirmwareUpgradeManager?
    fileprivate var dfuController: DFUServiceController?
    
    @objc public  var smpEstimatedSwapTime: TimeInterval = 10.0
    @objc public  var smpEraseAppSettings: Bool = true
    @objc public  var smpPipelineDepth: Int = 3
    @objc public  var smpByteAlignment: Int = 4
    
    fileprivate var smpDFUConfiguration:  FirmwareUpgradeConfiguration {
        return FirmwareUpgradeConfiguration(
            estimatedSwapTime: smpEstimatedSwapTime, eraseAppSettings: smpEraseAppSettings, pipelineDepth: smpPipelineDepth, byteAlignment: .init(rawValue: UInt64(smpByteAlignment)) ?? .fourByte)
    }
    
    private var currentDFUProtocol:DFUProtocolType = .NordicDFU
    
    fileprivate func  retryOTA () {
        debugPrint(#function)
        if self.currentDFUProtocol == .SMPDFU {
            if let manager = dfuManager ,manager.isPaused(){
                manager.resume()
                debugPrint("OTA Retry by resume")
            } else if let otaDevice = otaDevice {
                debugPrint("OTA Retry by restart with device:\(otaDevice),file:\(firmwarePath)")
               spmOTAWithPeripheral(otaDevice, file: firmwarePath)
            }
        }
    }
    
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
            let bleTransporter = McuMgrBleTransport(peripheral)
            bleTransporter.logDelegate = self.proxy
            bleTransporter.delegate = self.proxy
            let manager  = FirmwareUpgradeManager(transporter: bleTransporter, delegate: self.proxy)
            manager.mode = .confirmOnly
           
            self.dfuManager = manager
            try manager.start(images: package.images,using: smpDFUConfiguration)
            
        } catch  {
            completedHandel?(false,error);
        }
    }
#endif
    
    
    @objc public func otaWithPeripheral(_ peripheral:CBPeripheral,dfuProtocol:DFUProtocolType,firmareFilePath:String,otaProgress:@escaping ((Int,String) ->Void),completedHandel:@escaping ((Bool,Error?) -> Void)) {
#if targetEnvironment(simulator)
        completedHandel(false,NSError.init(domain: ErrorDomain, code: BPDFUError.simlatorDoesNotSupportDFU.rawValue, userInfo: [NSLocalizedDescriptionKey:"模拟器上不支持OTA升级"]))
#else
        
        guard FileManager.default.fileExists(atPath: firmareFilePath) else {
            completedHandel(false,NSError.init(domain: ErrorDomain, code: BPDFUError.invalidFirmwareFile.rawValue, userInfo: [NSLocalizedDescriptionKey:"未找到有效的固件文件:\(firmareFilePath)"]))
            return
        }
    
        self.otaProgress = otaProgress
        self.completedHandel = completedHandel
        self.currentDFUProtocol = dfuProtocol;
        self.otaDevice = peripheral
        self.firmwarePath = firmareFilePath
        
        switch dfuProtocol {
        case .NordicDFU:
            classicOTAWithPeripheral(peripheral, file: firmareFilePath)
        case .SMPDFU:
            spmOTAWithPeripheral(peripheral, file: firmareFilePath)
        }
#endif
    }
    
    
    func finishedOTA(_ successed: Bool,error:Error?) {
        completedHandel?(successed,error)
        completedHandel = nil
        otaProgress = nil
#if targetEnvironment(simulator)
    
#else
        dfuController = nil
        dfuManager = nil
#endif
    }
       
}


#if targetEnvironment(simulator)
#else
fileprivate class BPOTAManagerProxy: NSObject {
    unowned let manager: BPOTAManager
    private let maxRetryCount = 3
    private var currentRetryTime = 0
    
    required init(manager: BPOTAManager) {
        self.manager = manager
        super.init()
    }
    
    func finishedOTA(_ successed: Bool,error:Error?) {
        self.manager.finishedOTA(successed, error: error)
        currentRetryTime = 0
    }
}

extension BPOTAManagerProxy: DFUServiceDelegate,DFUProgressDelegate,LoggerDelegate {
    public func dfuStateDidChange(to state: DFUState) {
        debugPrint("升级状态：\(state),\(state.description)")
        if state == .completed {
            finishedOTA(true,error: nil)
        }
    }
    
    public func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
         debugPrint(error,message)
//        self.manager.completedHandel?(false,NSError.init(domain: ErrorDomain, code: error.rawValue, userInfo: [NSLocalizedDescriptionKey : message]))
        finishedOTA(false, error: NSError.init(domain: ErrorDomain, code: error.rawValue, userInfo: [NSLocalizedDescriptionKey : message]))
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
        var progress = 0
        switch newState {
        case .requestMcuMgrParameters:
            progress = 1
            debugPrint("REQUESTING MCUMGR PARAMETERS...")
        case .validate:
            progress = 2
            debugPrint("VALIDATING...")
        case .upload:
            progress = 3
            debugPrint( "UPLOADING...")
//        case .eraseAppSettings:
//            debugPrint("ERASING APP SETTINGS...")
        case .test:
            debugPrint("TESTING...")
        case .confirm:
            progress = 98
            debugPrint("CONFIRMING...")
        case .reset:
            progress = 99
            debugPrint("RESETTING...")
        case .success:
            debugPrint("UPLOAD COMPLETE")
       default:
            debugPrint("State:\(newState)")
            break
            
        }
        
        if progress > 0 {
            self.manager.otaProgress?(progress,"from:\(previousState) to \(newState)")
        }
    }
    
    public func upgradeDidComplete() {
        debugPrint(#function)
        finishedOTA(true, error: nil)
    }
    
    public func upgradeDidFail(inState state: FirmwareUpgradeState, with error: Error) {
        debugPrint(#function,state,error)
        if currentRetryTime < maxRetryCount {
            currentRetryTime += 1
            self.manager.retryOTA()
        } else {
           finishedOTA(false, error: error)
        }
    }
    
    public func upgradeDidCancel(state: FirmwareUpgradeState) {
        
//        self.manager.completedHandel?(false,NSError.init(domain: ErrorDomain, code: BPOTAManager.BPDFUError.dfuCancel.rawValue, userInfo: [NSLocalizedDescriptionKey : "取消升级，当前步骤：\(state)"]))
        finishedOTA(false, error: NSError.init(domain: ErrorDomain, code: BPOTAManager.BPDFUError.dfuCancel.rawValue, userInfo: [NSLocalizedDescriptionKey : "取消升级，当前步骤：\(state)"]))
    }
    
    public func uploadProgressDidChange(bytesSent: Int, imageSize: Int, timestamp: Date) {
        let currentProgress = Float(bytesSent) / Float(imageSize)
        var percent = Int(currentProgress * 100)
        percent = (percent > 2 ) ? percent : 2
        percent = (percent < 98 ) ? percent : 98
        let msg = "升级进度 已发送:\(bytesSent),总大小:\(imageSize),progress:\(currentProgress)   percent:\(percent)% -- \(timestamp)"
        self.manager.otaProgress?(percent,msg)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didChangeStateTo state: PeripheralState) {
         
    }
    
    public func log(_ msg: String, ofCategory category: McuMgrLogCategory, atLevel level: McuMgrLogLevel) {
         
    }
}


#endif
