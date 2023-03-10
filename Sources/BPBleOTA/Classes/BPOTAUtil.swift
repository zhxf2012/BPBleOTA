//
//  BPenOTAUtil.swift
//  BPenOTASDK
//
//  Created by xingfa on 2023/2/16.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - UTI

enum UTI: String, CaseIterable {
    case zip
    case bin
    
    // MARK: - Properties
    
    var typeIdentifiers: [String] {
        switch self {
        case .zip:
            return ["public.zip-archive", "com.pkware.zip-archive"]
        case .bin:
            return ["com.apple.macbinary-archive"]
        }
    }
    
    // MARK: - from()
    
    static func from(_ fileType: String) -> UTI? {
        return UTI.allCases.first {
            $0.typeIdentifiers.contains(fileType)
        }
    }
}

extension Data {
    
    internal struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
        public static let space = HexEncodingOptions(rawValue: 1 << 1)
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    internal func hexEncodedString(options: HexEncodingOptions = []) -> String {
        var format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        if options.contains(.space) {
            format.append(" ")
        }
        return map { String(format: format, $0) }.joined()
    }
    
}
