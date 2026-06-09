//
//  Log.swift
//

import os

nonisolated enum Log {
    private static let subsystem = "com.field-capture"

    private static let app = Logger(subsystem: subsystem, category: "app")
    private static let data = Logger(subsystem: subsystem, category: "data")
    private static let processing = Logger(subsystem: subsystem, category: "processing")

    static func appDebug(_ message: String) {
        app.debug("\(message, privacy: .public)")
    }

    static func dataInfo(_ message: String) {
        data.info("\(message, privacy: .public)")
    }

    static func processingInfo(_ message: String) {
        processing.info("\(message, privacy: .public)")
    }

    static func processingError(_ message: String) {
        processing.error("\(message, privacy: .public)")
    }
}
