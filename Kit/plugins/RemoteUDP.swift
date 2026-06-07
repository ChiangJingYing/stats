//
//  RemoteUDP.swift
//  Kit
//
//  Created by Codex on 26/05/2026.
//

import CryptoKit
import Compression
import Foundation
import Network

public enum RemoteUDPFanMode: String, Codable {
    case automatic
    case manual
}

public enum RemoteUDPControlMode: String, Codable {
    case monitorOnly
    case fullControl

    public var supportsControl: Bool {
        self == .fullControl
    }
}

public struct RemoteUDPMetricTelemetry: Codable, Equatable {
    public let id: String
    public let name: String
    public let value: Double
    public let unit: String

    public init(id: String, name: String, value: Double, unit: String) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
    }
}

public struct RemoteUDPFanTelemetry: Codable, Equatable {
    public let id: Int
    public let name: String
    public let rpm: Int
    public let minRpm: Int
    public let maxRpm: Int
    public let mode: RemoteUDPFanMode

    public init(id: Int, name: String, rpm: Int, minRpm: Int, maxRpm: Int, mode: RemoteUDPFanMode) {
        self.id = id
        self.name = name
        self.rpm = rpm
        self.minRpm = minRpm
        self.maxRpm = maxRpm
        self.mode = mode
    }
}

public struct RemoteUDPTelemetryPayload: Codable, Equatable {
    public let version: Int
    public let deviceId: String
    public let deviceName: String
    public let timestamp: TimeInterval
    public let cpuTemperature: Double?
    public let gpuTemperature: Double?
    public let cpuUsage: Double?
    public let gpuUsage: Double?
    public let cpuCoreTemperatures: [RemoteUDPMetricTelemetry]
    public let gpuCoreTemperatures: [RemoteUDPMetricTelemetry]
    public let cpuCoreUsages: [RemoteUDPMetricTelemetry]
    public let gpuCoreUsages: [RemoteUDPMetricTelemetry]
    public let fans: [RemoteUDPFanTelemetry]
    public let fanControlAvailable: Bool?
    public let commandChannelAvailable: Bool?
    public let controlMode: RemoteUDPControlMode
    public let controlProvider: String?
    public let helperIdentifier: String?

    private enum CodingKeys: String, CodingKey {
        case version
        case deviceId
        case deviceName
        case timestamp
        case cpuTemperature
        case gpuTemperature
        case cpuUsage
        case gpuUsage
        case cpuCoreTemperatures
        case gpuCoreTemperatures
        case cpuCoreUsages
        case gpuCoreUsages
        case fanControlAvailable
        case commandChannelAvailable
        case controlMode
        case controlProvider
        case helperIdentifier
        case fans
    }

    public init(
        version: Int = 1,
        deviceId: String,
        deviceName: String,
        timestamp: TimeInterval,
        cpuTemperature: Double?,
        gpuTemperature: Double?,
        cpuUsage: Double? = nil,
        gpuUsage: Double? = nil,
        cpuCoreTemperatures: [RemoteUDPMetricTelemetry] = [],
        gpuCoreTemperatures: [RemoteUDPMetricTelemetry] = [],
        cpuCoreUsages: [RemoteUDPMetricTelemetry] = [],
        gpuCoreUsages: [RemoteUDPMetricTelemetry] = [],
        fans: [RemoteUDPFanTelemetry],
        fanControlAvailable: Bool? = nil,
        commandChannelAvailable: Bool? = nil,
        controlMode: RemoteUDPControlMode = .monitorOnly,
        controlProvider: String? = nil,
        helperIdentifier: String? = nil
    ) {
        self.version = version
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.timestamp = timestamp
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.cpuUsage = cpuUsage
        self.gpuUsage = gpuUsage
        self.cpuCoreTemperatures = cpuCoreTemperatures
        self.gpuCoreTemperatures = gpuCoreTemperatures
        self.cpuCoreUsages = cpuCoreUsages
        self.gpuCoreUsages = gpuCoreUsages
        self.fanControlAvailable = fanControlAvailable
        self.commandChannelAvailable = commandChannelAvailable
        self.controlMode = controlMode
        self.controlProvider = controlProvider
        self.helperIdentifier = helperIdentifier
        self.fans = fans
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.deviceId = try container.decode(String.self, forKey: .deviceId)
        self.deviceName = try container.decode(String.self, forKey: .deviceName)
        self.timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        self.cpuTemperature = try container.decodeIfPresent(Double.self, forKey: .cpuTemperature)
        self.gpuTemperature = try container.decodeIfPresent(Double.self, forKey: .gpuTemperature)
        self.cpuUsage = try container.decodeIfPresent(Double.self, forKey: .cpuUsage)
        self.gpuUsage = try container.decodeIfPresent(Double.self, forKey: .gpuUsage)
        self.cpuCoreTemperatures = try container.decodeIfPresent([RemoteUDPMetricTelemetry].self, forKey: .cpuCoreTemperatures) ?? []
        self.gpuCoreTemperatures = try container.decodeIfPresent([RemoteUDPMetricTelemetry].self, forKey: .gpuCoreTemperatures) ?? []
        self.cpuCoreUsages = try container.decodeIfPresent([RemoteUDPMetricTelemetry].self, forKey: .cpuCoreUsages) ?? []
        self.gpuCoreUsages = try container.decodeIfPresent([RemoteUDPMetricTelemetry].self, forKey: .gpuCoreUsages) ?? []
        self.fanControlAvailable = try container.decodeIfPresent(Bool.self, forKey: .fanControlAvailable)
        self.commandChannelAvailable = try container.decodeIfPresent(Bool.self, forKey: .commandChannelAvailable)
        self.controlMode = try container.decodeIfPresent(RemoteUDPControlMode.self, forKey: .controlMode) ?? .monitorOnly
        self.controlProvider = try container.decodeIfPresent(String.self, forKey: .controlProvider)
        self.helperIdentifier = try container.decodeIfPresent(String.self, forKey: .helperIdentifier)
        self.fans = try container.decodeIfPresent([RemoteUDPFanTelemetry].self, forKey: .fans) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.deviceId, forKey: .deviceId)
        try container.encode(self.deviceName, forKey: .deviceName)
        try container.encode(self.timestamp, forKey: .timestamp)
        try container.encodeIfPresent(self.cpuTemperature, forKey: .cpuTemperature)
        try container.encodeIfPresent(self.gpuTemperature, forKey: .gpuTemperature)
        try container.encodeIfPresent(self.cpuUsage, forKey: .cpuUsage)
        try container.encodeIfPresent(self.gpuUsage, forKey: .gpuUsage)
        try container.encode(self.cpuCoreTemperatures, forKey: .cpuCoreTemperatures)
        try container.encode(self.gpuCoreTemperatures, forKey: .gpuCoreTemperatures)
        try container.encode(self.cpuCoreUsages, forKey: .cpuCoreUsages)
        try container.encode(self.gpuCoreUsages, forKey: .gpuCoreUsages)
        try container.encodeIfPresent(self.fanControlAvailable, forKey: .fanControlAvailable)
        try container.encodeIfPresent(self.commandChannelAvailable, forKey: .commandChannelAvailable)
        try container.encode(self.controlMode, forKey: .controlMode)
        try container.encodeIfPresent(self.controlProvider, forKey: .controlProvider)
        try container.encodeIfPresent(self.helperIdentifier, forKey: .helperIdentifier)
        try container.encode(self.fans, forKey: .fans)
    }
}

public enum RemoteUDPTelemetryCodec {
    private static let magic = Data("RUDPZ1".utf8)
    private static let headerSize = magic.count + MemoryLayout<UInt32>.size
    private static let compressionThreshold = 1200
    private static let algorithm = COMPRESSION_LZFSE

    public static func encode(_ payload: RemoteUDPTelemetryPayload, encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        let data = try encoder.encode(payload)
        guard data.count > self.compressionThreshold, let compressed = self.compress(data) else {
            return data
        }

        var envelope = Data()
        envelope.append(self.magic)
        envelope.append(contentsOf: self.bigEndianBytes(UInt32(data.count)))
        envelope.append(compressed)
        return envelope.count < data.count ? envelope : data
    }

    public static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> RemoteUDPTelemetryPayload {
        try decoder.decode(RemoteUDPTelemetryPayload.self, from: self.payloadData(from: data))
    }

    private static func payloadData(from data: Data) throws -> Data {
        guard data.starts(with: self.magic) else {
            return data
        }
        guard data.count > self.headerSize else {
            throw RemoteUDPError.invalidCompressedTelemetry
        }

        let sizeBytes = data.dropFirst(self.magic.count).prefix(MemoryLayout<UInt32>.size)
        let size = Int(sizeBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
        let compressed = data.dropFirst(self.headerSize)
        guard let decoded = self.decompress(Data(compressed), outputSize: size) else {
            throw RemoteUDPError.invalidCompressedTelemetry
        }
        return decoded
    }

    private static func bigEndianBytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
    }

    private static func compress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        return data.withUnsafeBytes { sourceBuffer in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            var outputSize = max(data.count / 2, 256)

            for _ in 0..<4 {
                var output = [UInt8](repeating: 0, count: outputSize)
                let count = compression_encode_buffer(&output, output.count, source, data.count, nil, self.algorithm)
                if count > 0 {
                    return Data(output.prefix(count))
                }
                outputSize *= 2
            }

            return nil
        }
    }

    private static func decompress(_ data: Data, outputSize: Int) -> Data? {
        guard outputSize >= 0 else { return nil }
        guard !data.isEmpty else { return outputSize == 0 ? Data() : nil }
        return data.withUnsafeBytes { sourceBuffer in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            var output = [UInt8](repeating: 0, count: outputSize)
            let count = compression_decode_buffer(&output, output.count, source, data.count, nil, self.algorithm)
            guard count == outputSize else { return nil }
            return Data(output)
        }
    }
}

public enum RemoteUDPFanCommandType: String, Codable {
    case setModeAuto
    case setModeManual
    case setSpeed
    case reset
}

public enum RemoteUDPValidationResult: Equatable {
    case accepted
    case rejected(String)
}

public struct RemoteUDPFanCommand: Codable, Equatable {
    public let version: Int
    public let deviceId: String
    public var timestamp: TimeInterval
    public let nonce: String
    public let commandId: String
    public let command: RemoteUDPFanCommandType
    public let fanId: Int?
    public var speed: Int?
    public var signature: String?

    public init(
        version: Int = 1,
        deviceId: String,
        timestamp: TimeInterval,
        nonce: String,
        commandId: String,
        command: RemoteUDPFanCommandType,
        fanId: Int? = nil,
        speed: Int? = nil,
        signature: String? = nil
    ) {
        self.version = version
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.nonce = nonce
        self.commandId = commandId
        self.command = command
        self.fanId = fanId
        self.speed = speed
        self.signature = signature
    }

    public mutating func sign(sharedSecret: String) {
        self.signature = Self.signature(for: self, sharedSecret: sharedSecret)
    }

    public func hasValidSignature(sharedSecret: String) -> Bool {
        guard let signature else { return false }
        return signature == Self.signature(for: self, sharedSecret: sharedSecret)
    }

    public static func validateSpeed(_ speed: Int, for fan: RemoteUDPFanTelemetry) -> RemoteUDPValidationResult {
        if speed < fan.minRpm {
            return .rejected("speed below minimum")
        }
        if speed > fan.maxRpm {
            return .rejected("speed above maximum")
        }
        return .accepted
    }

    private static func signature(for command: RemoteUDPFanCommand, sharedSecret: String) -> String {
        let key = SymmetricKey(data: Data(sharedSecret.utf8))
        let input = [
            "\(command.version)",
            command.deviceId,
            "\(command.timestamp)",
            command.nonce,
            command.commandId,
            command.command.rawValue,
            command.fanId.map(String.init) ?? "",
            command.speed.map(String.init) ?? ""
        ].joined(separator: "|")
        let mac = HMAC<SHA256>.authenticationCode(for: Data(input.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }
}

public struct RemoteUDPFanCommandAck: Codable, Equatable {
    public enum Status: String, Codable {
        case ok
        case rejected
        case failed
    }

    public let version: Int
    public let deviceId: String
    public let commandId: String
    public let status: Status
    public let message: String

    public init(version: Int = 1, deviceId: String, commandId: String, status: Status, message: String) {
        self.version = version
        self.deviceId = deviceId
        self.commandId = commandId
        self.status = status
        self.message = message
    }
}

public struct RemoteUDPDeviceState: Equatable {
    public let payload: RemoteUDPTelemetryPayload
    public let receivedAt: Date
    public let sourceHost: String?

    public init(payload: RemoteUDPTelemetryPayload, receivedAt: Date = Date(), sourceHost: String? = nil) {
        self.payload = payload
        self.receivedAt = receivedAt
        self.sourceHost = sourceHost
    }
}

public struct RemoteUDPDisplayOptions: Equatable {
    public let displayName: String
    public let showCPUTemperature: Bool
    public let showCPUUsage: Bool
    public let showGPUTemperature: Bool
    public let showGPUUsage: Bool
    public let showCPUCoreTemperatures: Bool
    public let showGPUCoreTemperatures: Bool
    public let showCPUCoreUsages: Bool
    public let showGPUCoreUsages: Bool
    public let showFanSpeed: Bool

    public init(
        displayName: String = "",
        showCPUTemperature: Bool = true,
        showCPUUsage: Bool = true,
        showGPUTemperature: Bool = false,
        showGPUUsage: Bool = false,
        showCPUCoreTemperatures: Bool = false,
        showGPUCoreTemperatures: Bool = false,
        showCPUCoreUsages: Bool = false,
        showGPUCoreUsages: Bool = false,
        showFanSpeed: Bool = true
    ) {
        self.displayName = displayName
        self.showCPUTemperature = showCPUTemperature
        self.showCPUUsage = showCPUUsage
        self.showGPUTemperature = showGPUTemperature
        self.showGPUUsage = showGPUUsage
        self.showCPUCoreTemperatures = showCPUCoreTemperatures
        self.showGPUCoreTemperatures = showGPUCoreTemperatures
        self.showCPUCoreUsages = showCPUCoreUsages
        self.showGPUCoreUsages = showGPUCoreUsages
        self.showFanSpeed = showFanSpeed
    }

    public static func fromStore() -> RemoteUDPDisplayOptions {
        RemoteUDPDisplayOptions(
            displayName: Store.shared.string(key: "RemoteUDP_displayName", defaultValue: ""),
            showCPUTemperature: Store.shared.bool(key: "RemoteUDP_display_cpuTemperature", defaultValue: true),
            showCPUUsage: Store.shared.bool(key: "RemoteUDP_display_cpuUsage", defaultValue: true),
            showGPUTemperature: Store.shared.bool(key: "RemoteUDP_display_gpuTemperature", defaultValue: false),
            showGPUUsage: Store.shared.bool(key: "RemoteUDP_display_gpuUsage", defaultValue: false),
            showCPUCoreTemperatures: Store.shared.bool(key: "RemoteUDP_display_cpuCoreTemperatures", defaultValue: false),
            showGPUCoreTemperatures: Store.shared.bool(key: "RemoteUDP_display_gpuCoreTemperatures", defaultValue: false),
            showCPUCoreUsages: Store.shared.bool(key: "RemoteUDP_display_cpuCoreUsages", defaultValue: false),
            showGPUCoreUsages: Store.shared.bool(key: "RemoteUDP_display_gpuCoreUsages", defaultValue: false),
            showFanSpeed: Store.shared.bool(key: "RemoteUDP_display_fanSpeed", defaultValue: true)
        )
    }
}

public enum RemoteUDPDisplayFormatter {
    public static func menuBarText(
        _ devices: [RemoteUDPDeviceState],
        now: Date = Date(),
        options: RemoteUDPDisplayOptions = .fromStore()
    ) -> String {
        guard let state = freshestDevice(from: devices) else { return "Remote -" }
        let payload = state.payload
        var values = [displayName(for: payload, options: options)]

        if options.showCPUTemperature, let cpu = payload.cpuTemperature {
            values.append("CPU \(temperatureValue(cpu))")
        }
        if options.showCPUUsage, let cpuUsage = payload.cpuUsage {
            values.append("CPU \(percentageValue(cpuUsage))")
        }
        if options.showGPUTemperature, let gpu = payload.gpuTemperature {
            values.append("GPU \(temperatureValue(gpu))")
        }
        if options.showGPUUsage, let gpuUsage = payload.gpuUsage {
            values.append("GPU \(percentageValue(gpuUsage))")
        }
        if options.showCPUCoreTemperatures {
            values.append(contentsOf: payload.cpuCoreTemperatures.map { "\($0.name) \(temperatureValue($0.value))" })
        }
        if options.showGPUCoreTemperatures {
            values.append(contentsOf: payload.gpuCoreTemperatures.map { "\($0.name) \(temperatureValue($0.value))" })
        }
        if options.showCPUCoreUsages {
            values.append(contentsOf: payload.cpuCoreUsages.map { "\($0.name) \(percentageValue($0.value))" })
        }
        if options.showGPUCoreUsages {
            values.append(contentsOf: payload.gpuCoreUsages.map { "\($0.name) \(percentageValue($0.value))" })
        }
        if options.showFanSpeed {
            values.append(contentsOf: payload.fans.map { "\($0.name) \($0.rpm)rpm" })
        }

        return values.joined(separator: " ")
    }

    public static func stackValues(
        _ devices: [RemoteUDPDeviceState],
        now: Date = Date(),
        options: RemoteUDPDisplayOptions = .fromStore()
    ) -> [Stack_t] {
        guard let state = freshestDevice(from: devices) else {
            return [Stack_t(key: "Remote", value: "-")]
        }

        let payload = state.payload
        var values: [Stack_t] = [Stack_t(
            key: "Device",
            value: displayName(for: payload, options: options),
            singleRow: true
        )]
        if options.showCPUTemperature, let cpu = payload.cpuTemperature {
            values.append(Stack_t(key: "CPU", value: temperatureValue(cpu)))
        }
        if options.showCPUUsage, let cpuUsage = payload.cpuUsage {
            values.append(Stack_t(key: "CPU Usage", value: percentageValue(cpuUsage)))
        }
        if options.showGPUTemperature, let gpu = payload.gpuTemperature {
            values.append(Stack_t(key: "GPU", value: temperatureValue(gpu)))
        }
        if options.showGPUUsage, let gpuUsage = payload.gpuUsage {
            values.append(Stack_t(key: "GPU Usage", value: percentageValue(gpuUsage)))
        }
        if options.showCPUCoreTemperatures {
            values.append(contentsOf: payload.cpuCoreTemperatures.map { Stack_t(key: $0.name, value: temperatureValue($0.value)) })
        }
        if options.showGPUCoreTemperatures {
            values.append(contentsOf: payload.gpuCoreTemperatures.map { Stack_t(key: $0.name, value: temperatureValue($0.value)) })
        }
        if options.showCPUCoreUsages {
            values.append(contentsOf: payload.cpuCoreUsages.map { Stack_t(key: $0.name, value: percentageValue($0.value)) })
        }
        if options.showGPUCoreUsages {
            values.append(contentsOf: payload.gpuCoreUsages.map { Stack_t(key: $0.name, value: percentageValue($0.value)) })
        }
        if options.showFanSpeed {
            values.append(contentsOf: payload.fans.map { Stack_t(key: $0.name, value: "\($0.rpm)") })
        }
        return values
    }

    public static func settingsSummary(_ devices: [RemoteUDPDeviceState]) -> String {
        guard !devices.isEmpty else { return localizedString("No devices") }
        return devices.map { detailedSummary($0) }.joined(separator: "\n")
    }

    public static func detailedSummary(_ state: RemoteUDPDeviceState) -> String {
        let payload = state.payload
        let cpu = summary(label: "CPU", temperature: payload.cpuTemperature, usage: payload.cpuUsage)
        let gpu = summary(label: "GPU", temperature: payload.gpuTemperature, usage: payload.gpuUsage)
        let fans = payload.fans.map { "\($0.name) \($0.rpm) RPM [\($0.minRpm)-\($0.maxRpm)]" }.joined(separator: ", ")
        let cpuTemps = metricsSummary(payload.cpuCoreTemperatures)
        let gpuTemps = metricsSummary(payload.gpuCoreTemperatures)
        let cpuUsage = metricsSummary(payload.cpuCoreUsages, percentage: true)
        let gpuUsage = metricsSummary(payload.gpuCoreUsages, percentage: true)
        let controlState = payload.controlMode == .fullControl ? "Full control" : "Monitor only"
        return [
            "\(payload.deviceName) [\(controlState)]: \(cpu), \(gpu), \(fans)",
            cpuTemps.isEmpty ? nil : "CPU temperatures: \(cpuTemps)",
            cpuUsage.isEmpty ? nil : "CPU usage: \(cpuUsage)",
            gpuTemps.isEmpty ? nil : "GPU temperatures: \(gpuTemps)",
            gpuUsage.isEmpty ? nil : "GPU usage: \(gpuUsage)"
        ].compactMap { $0 }.joined(separator: "\n")
    }

    private static func freshestDevice(from devices: [RemoteUDPDeviceState]) -> RemoteUDPDeviceState? {
        devices.max { $0.receivedAt < $1.receivedAt }
    }

    private static func displayName(for payload: RemoteUDPTelemetryPayload, options: RemoteUDPDisplayOptions) -> String {
        let customName = options.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return customName.isEmpty ? payload.deviceName : customName
    }

    private static func temperatureValue(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    private static func percentageValue(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func summary(label: String, temperature: Double?, usage: Double?) -> String {
        let temp = temperature.map { String(format: "%.1f C", $0) } ?? "-"
        let load = usage.map { "\(Int(($0 * 100).rounded()))%" } ?? "-"
        return "\(label) \(temp) / \(load)"
    }

    private static func metricsSummary(_ metrics: [RemoteUDPMetricTelemetry], percentage: Bool = false) -> String {
        metrics.map { metric in
            if percentage {
                return "\(metric.name) \(Int((metric.value * 100).rounded()))%"
            }
            return "\(metric.name) \(String(format: "%.1f", metric.value))\(metric.unit)"
        }.joined(separator: ", ")
    }
}

public final class RemoteUDPCommandValidator {
    private let sharedSecret: String
    private let now: () -> TimeInterval
    private let allowedClockSkew: TimeInterval
    private let maxTrackedNonces: Int
    private var seenNonces: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "eu.exelban.Stats.RemoteUDP.CommandValidator")

    public init(
        sharedSecret: String,
        now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        allowedClockSkew: TimeInterval = 30,
        maxTrackedNonces: Int = 4096
    ) {
        self.sharedSecret = sharedSecret
        self.now = now
        self.allowedClockSkew = allowedClockSkew
        self.maxTrackedNonces = max(1, maxTrackedNonces)
    }

    public func validate(_ command: RemoteUDPFanCommand) -> RemoteUDPValidationResult {
        guard command.version == 1 else {
            return .rejected("unsupported version")
        }
        guard !self.sharedSecret.isEmpty, command.hasValidSignature(sharedSecret: self.sharedSecret) else {
            return .rejected("invalid signature")
        }
        guard abs(self.now() - command.timestamp) <= self.allowedClockSkew else {
            return .rejected("stale command")
        }
        guard !command.nonce.isEmpty else {
            return .rejected("missing nonce")
        }

        return self.queue.sync {
            self.pruneSeenNonces(now: self.now())
            if self.seenNonces[command.nonce] != nil {
                return .rejected("replayed command")
            }
            self.seenNonces[command.nonce] = command.timestamp
            self.trimSeenNoncesToLimit()
            return .accepted
        }
    }

    internal var trackedNonceCount: Int {
        self.queue.sync { self.seenNonces.count }
    }

    private func pruneSeenNonces(now: TimeInterval) {
        let cutoff = now - self.allowedClockSkew
        self.seenNonces = self.seenNonces.filter { $0.value >= cutoff }
    }

    private func trimSeenNoncesToLimit() {
        guard self.seenNonces.count > self.maxTrackedNonces else { return }
        let overflow = self.seenNonces.count - self.maxTrackedNonces
        let oldestKeys = self.seenNonces
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value < rhs.value
            }
            .prefix(overflow)
            .map(\.key)

        oldestKeys.forEach { self.seenNonces.removeValue(forKey: $0) }
    }
}

public final class RemoteUDPSender {
    private let queue: DispatchQueue
    private var connections: [String: NWConnection] = [:]

    public init(queue: DispatchQueue = DispatchQueue(label: "eu.exelban.Stats.RemoteUDP.Sender")) {
        self.queue = queue
    }

    public func send(_ data: Data, host: String, port: UInt16, completion: ((Error?) -> Void)? = nil) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            completion?(RemoteUDPError.invalidPort)
            return
        }

        self.queue.async {
            let key = Self.connectionKey(host: host, port: port)
            let connection = self.connection(for: host, port: nwPort, key: key)
            connection.send(content: data, completion: .contentProcessed { [weak self, weak connection] error in
                if error != nil, let connection {
                    self?.invalidateConnection(connection, forKey: key)
                }
                completion?(error)
            })
        }
    }

    private func connection(for host: String, port: NWEndpoint.Port, key: String) -> NWConnection {
        if let existingConnection = self.connections[key] {
            return existingConnection
        }

        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .udp)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let connection else { return }

            switch state {
            case let .failed(error):
                debug("remote UDP sender failed for \(key): \(error)")
                self?.invalidateConnection(connection, forKey: key)
            case .cancelled:
                self?.removeConnection(connection, forKey: key)
            default:
                break
            }
        }
        connection.start(queue: self.queue)
        self.connections[key] = connection

        return connection
    }

    private func invalidateConnection(_ connection: NWConnection, forKey key: String) {
        self.queue.async {
            self.removeConnection(connection, forKey: key)
            connection.cancel()
        }
    }

    private func removeConnection(_ connection: NWConnection, forKey key: String) {
        guard let cachedConnection = self.connections[key], cachedConnection === connection else { return }
        self.connections.removeValue(forKey: key)
    }

    private static func connectionKey(host: String, port: UInt16) -> String {
        "\(host):\(port)"
    }
}

public final class RemoteUDPReceiver {
    private struct ConnectionState {
        let connection: NWConnection
        var lastActivityAt: Date
    }

    private let port: UInt16
    private let queue: DispatchQueue
    private let now: () -> Date
    private let connectionIdleTTL: TimeInterval
    private let handler: (Data, NWEndpoint) -> Void
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: ConnectionState] = [:]

    public init(
        port: UInt16,
        queue: DispatchQueue = DispatchQueue(label: "eu.exelban.Stats.RemoteUDP.Receiver"),
        now: @escaping () -> Date = Date.init,
        connectionIdleTTL: TimeInterval = 120,
        handler: @escaping (Data, NWEndpoint) -> Void
    ) {
        self.port = port
        self.queue = queue
        self.now = now
        self.connectionIdleTTL = max(1, connectionIdleTTL)
        self.handler = handler
    }

    public func start() throws {
        guard self.listener == nil else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: self.port) else {
            throw RemoteUDPError.invalidPort
        }

        let listener = try NWListener(using: .udp, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            let key = ObjectIdentifier(connection)
            connection.stateUpdateHandler = { [weak self, weak connection] state in
                guard let self, let connection else { return }
                switch state {
                case .failed, .cancelled:
                    self.removeConnection(connection)
                default:
                    break
                }
            }
            self.connections[key] = ConnectionState(connection: connection, lastActivityAt: self.now())
            connection.start(queue: self.queue)
            self.receive(on: connection)
            self.pruneConnections(now: self.now())
        }
        listener.start(queue: self.queue)
        self.listener = listener
    }

    public func stop() {
        self.queue.sync {
            self.connections.values.forEach { $0.connection.cancel() }
            self.connections.removeAll()
            self.listener?.cancel()
            self.listener = nil
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self else { return }
            guard let connection else { return }
            let key = ObjectIdentifier(connection)
            guard self.connections[key] != nil else { return }

            if let data, !data.isEmpty {
                self.touchConnection(connection, at: self.now())
                self.handler(data, connection.endpoint)
            }
            self.pruneConnections(now: self.now())

            guard error == nil, self.connections[key] != nil else {
                self.removeConnection(connection)
                return
            }
            self.receive(on: connection)
        }
    }

    internal var connectionCount: Int {
        self.queue.sync { self.connections.count }
    }

    internal func debugPruneConnections() {
        self.queue.sync {
            self.pruneConnections(now: self.now())
        }
    }

    private func touchConnection(_ connection: NWConnection, at date: Date) {
        let key = ObjectIdentifier(connection)
        guard var state = self.connections[key] else { return }
        state.lastActivityAt = date
        self.connections[key] = state
    }

    private func pruneConnections(now: Date) {
        let cutoff = now.addingTimeInterval(-self.connectionIdleTTL)
        let idleKeys = self.connections.compactMap { key, state in
            state.lastActivityAt < cutoff ? key : nil
        }

        idleKeys.forEach { key in
            guard let state = self.connections.removeValue(forKey: key) else { return }
            state.connection.cancel()
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        self.queue.async {
            self.connections.removeValue(forKey: ObjectIdentifier(connection))
        }
    }
}

public enum RemoteUDPError: Error {
    case invalidPort
    case invalidCompressedTelemetry
}

public final class RemoteUDP {
    public static let shared = RemoteUDP()

    public typealias FanCommandHandler = (RemoteUDPFanCommand) -> RemoteUDPFanCommandAck

    public var fanCommandHandler: FanCommandHandler?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let sender: RemoteUDPSender
    private let now: () -> Date
    private let deviceTTL: TimeInterval
    private let maxTrackedDevices: Int
    private let queue = DispatchQueue(label: "eu.exelban.Stats.RemoteUDP.Manager")
    private var telemetryReceiver: RemoteUDPReceiver?
    private var commandReceiver: RemoteUDPReceiver?
    private var commandValidator: RemoteUDPCommandValidator?
    private var devices: [String: RemoteUDPDeviceState] = [:]
    private var cpuUsage: Double?
    private var cpuCoreUsages: [RemoteUDPMetricTelemetry] = []
    private var gpuUsage: Double?
    private var gpuCoreUsages: [RemoteUDPMetricTelemetry] = []

    public init(
        sender: RemoteUDPSender = RemoteUDPSender(),
        now: @escaping () -> Date = Date.init,
        deviceTTL: TimeInterval = 120,
        maxTrackedDevices: Int = 256
    ) {
        self.sender = sender
        self.now = now
        self.deviceTTL = max(1, deviceTTL)
        self.maxTrackedDevices = max(1, maxTrackedDevices)
    }

    public var receivedDevices: [RemoteUDPDeviceState] {
        self.queue.sync {
            self.pruneDevices(now: self.now())
            return self.sortedDevices()
        }
    }

    public var currentCPUUsage: Double? {
        self.queue.sync { self.cpuUsage }
    }

    public var currentCPUCoreUsages: [RemoteUDPMetricTelemetry] {
        self.queue.sync { self.cpuCoreUsages }
    }

    public var currentGPUUsage: Double? {
        self.queue.sync { self.gpuUsage }
    }

    public var currentGPUCoreUsages: [RemoteUDPMetricTelemetry] {
        self.queue.sync { self.gpuCoreUsages }
    }

    public func updateCPUUsage(total: Double?, cores: [RemoteUDPMetricTelemetry]) {
        self.queue.sync {
            self.cpuUsage = total
            self.cpuCoreUsages = cores
        }
    }

    public func updateGPUUsage(total: Double?, cores: [RemoteUDPMetricTelemetry]) {
        self.queue.sync {
            self.gpuUsage = total
            self.gpuCoreUsages = cores
        }
    }

    public func reload() {
        self.stop()

        if Store.shared.bool(key: "RemoteUDP_receiveTelemetry", defaultValue: false) {
            let port = self.portValue(key: "RemoteUDP_telemetryListenPort", defaultValue: 7530)
            let receiver = RemoteUDPReceiver(port: port, now: self.now, connectionIdleTTL: self.deviceTTL) { [weak self] data, endpoint in
                self?.handleTelemetry(data, endpoint: endpoint)
            }
            do {
                try receiver.start()
                self.telemetryReceiver = receiver
            } catch {
                debug("remote UDP telemetry listener failed: \(error)")
            }
        }

        if Store.shared.bool(key: "RemoteUDP_receiveCommands", defaultValue: false) {
            let port = self.portValue(key: "RemoteUDP_commandListenPort", defaultValue: 7531)
            let secret = Store.shared.string(key: "RemoteUDP_sharedSecret", defaultValue: "")
            self.commandValidator = RemoteUDPCommandValidator(sharedSecret: secret, now: { self.now().timeIntervalSince1970 })
            let receiver = RemoteUDPReceiver(port: port, now: self.now, connectionIdleTTL: self.deviceTTL) { [weak self] data, endpoint in
                self?.handleCommand(data, endpoint: endpoint)
            }
            do {
                try receiver.start()
                self.commandReceiver = receiver
            } catch {
                debug("remote UDP command listener failed: \(error)")
            }
        }
    }

    public func stop() {
        self.telemetryReceiver?.stop()
        self.commandReceiver?.stop()
        self.telemetryReceiver = nil
        self.commandReceiver = nil
        self.commandValidator = nil
        self.queue.sync {
            self.devices.removeAll()
            self.cpuUsage = nil
            self.cpuCoreUsages = []
            self.gpuUsage = nil
            self.gpuCoreUsages = []
        }
    }

    public func sendTelemetry(_ payload: RemoteUDPTelemetryPayload) {
        guard Store.shared.bool(key: "RemoteUDP_sendTelemetry", defaultValue: false) else { return }
        let host = Store.shared.string(key: "RemoteUDP_targetHost", defaultValue: "")
        guard !host.isEmpty else { return }

        do {
            let data = try RemoteUDPTelemetryCodec.encode(payload, encoder: self.encoder)
            let port = self.portValue(key: "RemoteUDP_telemetryTargetPort", defaultValue: 7530)
            self.sender.send(data, host: host, port: port)
        } catch {
            debug("remote UDP telemetry encode failed: \(error)")
        }
    }

    public func sendCommand(_ command: RemoteUDPFanCommand) {
        let host = Store.shared.string(key: "RemoteUDP_targetHost", defaultValue: "")
        guard !host.isEmpty else { return }

        self.sendCommand(command, host: host)
    }

    public func sendCommand(_ command: RemoteUDPFanCommand, host: String) {
        guard !host.isEmpty else { return }

        do {
            let data = try self.encoder.encode(command)
            let port = self.portValue(key: "RemoteUDP_commandTargetPort", defaultValue: 7531)
            self.sender.send(data, host: host, port: port)
        } catch {
            debug("remote UDP command encode failed: \(error)")
        }
    }

    public func sendFanCommand(
        deviceId: String,
        command: RemoteUDPFanCommandType,
        fanId: Int? = nil,
        speed: Int? = nil,
        host: String? = nil
    ) {
        var payload = RemoteUDPFanCommand(
            deviceId: deviceId,
            timestamp: Date().timeIntervalSince1970,
            nonce: UUID().uuidString,
            commandId: UUID().uuidString,
            command: command,
            fanId: fanId,
            speed: speed
        )
        payload.sign(sharedSecret: Store.shared.string(key: "RemoteUDP_sharedSecret", defaultValue: ""))
        if let host, !host.isEmpty {
            self.sendCommand(payload, host: host)
        } else {
            self.sendCommand(payload)
        }
    }

    private func handleTelemetry(_ data: Data, endpoint: NWEndpoint) {
        do {
            let payload = try RemoteUDPTelemetryCodec.decode(data, decoder: self.decoder)
            let state = RemoteUDPDeviceState(payload: payload, receivedAt: self.now(), sourceHost: Self.host(from: endpoint))
            self.queue.sync {
                self.pruneDevices(now: self.now())
                self.devices[payload.deviceId] = state
                self.trimDevicesToLimit()
            }
            NotificationCenter.default.post(name: .remoteUDPTelemetry, object: self, userInfo: ["state": state])
        } catch {
            debug("remote UDP telemetry decode failed: \(error)")
        }
    }

    private func handleCommand(_ data: Data, endpoint: NWEndpoint) {
        do {
            let command = try self.decoder.decode(RemoteUDPFanCommand.self, from: data)
            let ack = self.execute(command)
            self.reply(ack, to: endpoint)
            NotificationCenter.default.post(name: .remoteUDPCommandAck, object: self, userInfo: ["ack": ack])
        } catch {
            debug("remote UDP command decode failed: \(error)")
        }
    }

    private func execute(_ command: RemoteUDPFanCommand) -> RemoteUDPFanCommandAck {
        guard let validator = self.commandValidator else {
            return RemoteUDPFanCommandAck(deviceId: command.deviceId, commandId: command.commandId, status: .rejected, message: "command receiver disabled")
        }
        switch validator.validate(command) {
        case .accepted:
            guard let handler = self.fanCommandHandler else {
                return RemoteUDPFanCommandAck(deviceId: command.deviceId, commandId: command.commandId, status: .failed, message: "fan command handler unavailable")
            }
            return handler(command)
        case let .rejected(reason):
            return RemoteUDPFanCommandAck(deviceId: command.deviceId, commandId: command.commandId, status: .rejected, message: reason)
        }
    }

    private func reply(_ ack: RemoteUDPFanCommandAck, to endpoint: NWEndpoint) {
        guard case let .hostPort(host, port) = endpoint else { return }
        do {
            let data = try self.encoder.encode(ack)
            self.sender.send(data, host: "\(host)", port: port.rawValue)
        } catch {
            debug("remote UDP ack encode failed: \(error)")
        }
    }

    private func portValue(key: String, defaultValue: Int) -> UInt16 {
        let port = Store.shared.int(key: key, defaultValue: defaultValue)
        guard port > 0, port <= Int(UInt16.max) else {
            return UInt16(defaultValue)
        }
        return UInt16(port)
    }

    private static func host(from endpoint: NWEndpoint) -> String? {
        guard case let .hostPort(host, _) = endpoint else { return nil }
        return "\(host)"
    }

    internal var deviceCount: Int {
        self.queue.sync { self.devices.count }
    }

    internal func debugSetDevices(_ devices: [String: RemoteUDPDeviceState]) {
        self.queue.sync {
            self.devices = devices
        }
    }

    private func pruneDevices(now: Date) {
        let cutoff = now.addingTimeInterval(-self.deviceTTL)
        self.devices = self.devices.filter { $0.value.receivedAt >= cutoff }
        self.trimDevicesToLimit()
    }

    private func trimDevicesToLimit() {
        guard self.devices.count > self.maxTrackedDevices else { return }
        let overflow = self.devices.count - self.maxTrackedDevices
        let oldestKeys = self.devices
            .sorted { lhs, rhs in
                if lhs.value.receivedAt == rhs.value.receivedAt {
                    return lhs.key < rhs.key
                }
                return lhs.value.receivedAt < rhs.value.receivedAt
            }
            .prefix(overflow)
            .map(\.key)

        oldestKeys.forEach { self.devices.removeValue(forKey: $0) }
    }

    private func sortedDevices() -> [RemoteUDPDeviceState] {
        self.devices.values.sorted { lhs, rhs in
            if lhs.payload.deviceName == rhs.payload.deviceName {
                return lhs.receivedAt > rhs.receivedAt
            }
            return lhs.payload.deviceName < rhs.payload.deviceName
        }
    }
}
