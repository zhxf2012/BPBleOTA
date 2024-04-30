//
//  McuMgrPackage.swift
//  nRF Connect Device Manager
//
//  Created by Dinesh Harjani on 18/1/22.
//  Copyright © 2022 Nordic Semiconductor ASA. All rights reserved.
//

 

#if targetEnvironment(simulator)
#else

import Foundation
import iOSMcuManagerLibrary
import ZIPFoundation

// MARK: - McuMgrPackage

public struct McuMgrPackage {
    
    let images: [ImageManager.Image]
    
    // MARK: - Init
    
    init(from url: URL) throws {
        switch UTI.forFile(url) {
        case .bin:
            self.images = try Self.extractImageFromBinFile(from: url)
        case .zip:
            self.images = try Self.extractImageFromZipFile(from: url)
        default:
            throw McuMgrPackage.Error.notAValidDocument
        }
    }
    
    // MARK: - API
    
    func imageName(at index: Int) -> String {
        let coreName: String
        switch images[index].image {
        case 0: 
            coreName = "App Core"
        case 1: 
            coreName = "Net Core"
        default: 
            coreName = "Image \(index)"
        }
        return "\(coreName) Slot \(images[index].slot)"
    }
    
    func sizeString() -> String {
        var sizeString = ""
        for (i, image) in images.enumerated() {
            sizeString += "\(image.data.count) bytes (\(imageName(at: i)))"
            guard i != images.count - 1 else { continue }
            sizeString += "\n"
        }
        return sizeString
    }
    
    func hashString() throws -> String {
        var result = ""
        for (i, image) in images.enumerated() {
            let hashString = image.hash.hexEncodedString(options: .upperCase)
            result += "0x\(hashString.prefix(6))...\(hashString.suffix(6)) (\(imageName(at: i)))"
            guard i != images.count - 1 else { continue }
            result += "\n"
        }
        return result
    }
}

// MARK: - McuMgrPackage.Error

extension McuMgrPackage {
    
    enum Error: Swift.Error, LocalizedError {
        case deniedAccessToScopedResource, notAValidDocument, unableToAccessCacheDirectory
        case manifestFileNotFound, manifestImageNotFound
        
        var errorDescription: String? {
            switch self {
            case .deniedAccessToScopedResource:
                return "Access to Scoped Resource (iCloud?) Denied."
            case .notAValidDocument:
                return "This is not a valid file for DFU."
            case .unableToAccessCacheDirectory:
                return "We were unable to access the Cache Directory."
            case .manifestFileNotFound:
                return "DFU Manifest File not found."
            case .manifestImageNotFound:
                return "DFU Image specified in Manifest not found."
            }
        }
    }
}

// MARK: - Private

fileprivate extension McuMgrPackage {
    
    static func extractImageFromBinFile(from url: URL) throws -> [ImageManager.Image] {
        let binData = try Data(contentsOf: url)
        let binHash = try McuMgrImage(data: binData).hash
        return [ImageManager.Image(image: 0, hash: binHash, data: binData)]
    }
    
    static func extractImageFromZipFile(from url: URL) throws -> [ImageManager.Image] {
        guard let cacheDirectoryPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
            throw McuMgrPackage.Error.unableToAccessCacheDirectory
        }
        let cacheDirectoryURL = URL(fileURLWithPath: cacheDirectoryPath, isDirectory: true)
        
        let fileManager = FileManager()
        let contentURLs = try fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        contentURLs.forEach { url in
            _ = try? fileManager.removeItem(at: url)
        }
        
        try fileManager.unzipItem(at: url, to: cacheDirectoryURL)
        let unzippedURLs = try fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: nil, options: [])
        
        guard let dfuManifestURL = unzippedURLs.first(where: { $0.pathExtension == "json" }) else {
            throw McuMgrPackage.Error.manifestFileNotFound
        }
        let manifest = try McuMgrManifest(from: dfuManifestURL)
        let images = try manifest.files.compactMap { manifestFile -> ImageManager.Image in
            guard let imageURL = unzippedURLs.first(where: { $0.absoluteString.contains(manifestFile.file) }) else {
                throw McuMgrPackage.Error.manifestImageNotFound
            }
            let imageData = try Data(contentsOf: imageURL)
            let imageHash = try McuMgrImage(data: imageData).hash
            return ImageManager.Image(manifestFile, hash: imageHash, data: imageData)
        }
        try unzippedURLs.forEach { url in
            try fileManager.removeItem(at: url)
        }
        
        return images
    }
}

#endif
