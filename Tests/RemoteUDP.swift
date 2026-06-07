//
//  RemoteUDP.swift
//  Tests
//
//  Created by Codex on 26/05/2026.
//

import XCTest
import Network
@testable import Kit

final class RemoteUDPTests: XCTestCase {
    private static func receiverConnectionCount(_ receiver: RemoteUDPReceiver) -> Int {
        receiver.connectionCount
    }

    private func command(deviceId: String = "device-1", timestamp: TimeInterval, nonce: String) -> RemoteUDPFanCommand {
        var command = RemoteUDPFanCommand(
            deviceId: deviceId,
            timestamp: timestamp,
            nonce: nonce,
            commandId: UUID().uuidString,
            command: .reset
        )
        command.sign(sharedSecret: "secret")
        return command
    }

    private func telemetryState(id: String, name: String, receivedAt: TimeInterval) -> RemoteUDPDeviceState {
        RemoteUDPDeviceState(
            payload: RemoteUDPTelemetryPayload(
                deviceId: id,
                deviceName: name,
                timestamp: receivedAt,
                cpuTemperature: 48,
                gpuTemperature: nil,
                fans: []
            ),
            receivedAt: Date(timeIntervalSince1970: receivedAt)
        )
    }

    func testTelemetryPayloadRoundTrip() throws {
        let payload = RemoteUDPTelemetryPayload(
            deviceId: "device-1",
            deviceName: "Studio",
            timestamp: 1_779_753_600,
            cpuTemperature: 48.5,
            gpuTemperature: 43.25,
            cpuUsage: 0.42,
            gpuUsage: 0.36,
            cpuCoreTemperatures: [
                RemoteUDPMetricTelemetry(id: "cpu-p0", name: "P-Core 0", value: 52.5, unit: "C")
            ],
            gpuCoreTemperatures: [
                RemoteUDPMetricTelemetry(id: "gpu-core", name: "GPU Core", value: 43.25, unit: "C")
            ],
            cpuCoreUsages: [
                RemoteUDPMetricTelemetry(id: "cpu-0", name: "CPU Core 0", value: 0.6, unit: "%")
            ],
            gpuCoreUsages: [
                RemoteUDPMetricTelemetry(id: "gpu", name: "GPU", value: 0.36, unit: "%")
            ],
            fans: [
                RemoteUDPFanTelemetry(id: 0, name: "Left", rpm: 2100, minRpm: 1200, maxRpm: 5200, mode: .automatic)
            ],
            fanControlAvailable: true,
            commandChannelAvailable: true,
            controlMode: .fullControl,
            controlProvider: "app-proxy-smc-helper",
            helperIdentifier: "eu.exelban.Stats.SMC.Helper"
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(RemoteUDPTelemetryPayload.self, from: data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.deviceId, "device-1")
        XCTAssertEqual(decoded.cpuTemperature, 48.5)
        XCTAssertEqual(decoded.cpuUsage, 0.42)
        XCTAssertEqual(decoded.cpuCoreTemperatures.first?.name, "P-Core 0")
        XCTAssertEqual(decoded.gpuCoreUsages.first?.value, 0.36)
        XCTAssertEqual(decoded.fans.first?.maxRpm, 5200)
        XCTAssertEqual(decoded.controlMode, .fullControl)
        XCTAssertEqual(decoded.commandChannelAvailable, true)
        XCTAssertEqual(decoded.helperIdentifier, "eu.exelban.Stats.SMC.Helper")
    }

    func testTelemetryPayloadDecodesLegacyPayloadWithoutNewMetrics() throws {
        let legacy = Data("""
        {
          "version": 1,
          "deviceId": "legacy-device",
          "deviceName": "Legacy",
          "timestamp": 1779753600,
          "cpuTemperature": 47.5,
          "gpuTemperature": null,
          "fans": []
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(RemoteUDPTelemetryPayload.self, from: legacy)

        XCTAssertEqual(decoded.deviceId, "legacy-device")
        XCTAssertNil(decoded.cpuUsage)
        XCTAssertTrue(decoded.cpuCoreTemperatures.isEmpty)
        XCTAssertTrue(decoded.gpuCoreUsages.isEmpty)
        XCTAssertEqual(decoded.controlMode, .monitorOnly)
        XCTAssertNil(decoded.commandChannelAvailable)
    }

    func testTelemetryCodecCompressesLargePayloadAndRoundTrips() throws {
        let coreTemperatures = (0..<24).map {
            RemoteUDPMetricTelemetry(id: "cpu-temp-\($0)", name: "CPU core \($0)", value: 50 + Double($0), unit: "C")
        }
        let coreUsages = (0..<24).map {
            RemoteUDPMetricTelemetry(id: "cpu-\($0)", name: "CPU core \($0)", value: Double($0) / 100, unit: "%")
        }
        let payload = RemoteUDPTelemetryPayload(
            deviceId: "large-device",
            deviceName: "Large",
            timestamp: 1_779_753_600,
            cpuTemperature: 58,
            gpuTemperature: 47,
            cpuUsage: 0.57,
            gpuUsage: 0.08,
            cpuCoreTemperatures: coreTemperatures,
            gpuCoreTemperatures: coreTemperatures,
            cpuCoreUsages: coreUsages,
            gpuCoreUsages: coreUsages,
            fans: [
                RemoteUDPFanTelemetry(id: 0, name: "Main", rpm: 2100, minRpm: 1200, maxRpm: 5200, mode: .automatic)
            ],
            fanControlAvailable: true,
            commandChannelAvailable: true,
            controlMode: .fullControl
        )
        let raw = try JSONEncoder().encode(payload)
        let encoded = try RemoteUDPTelemetryCodec.encode(payload)
        let decoded = try RemoteUDPTelemetryCodec.decode(encoded)

        XCTAssertGreaterThan(raw.count, 1200)
        XCTAssertLessThan(encoded.count, raw.count)
        XCTAssertEqual(decoded.deviceId, "large-device")
        XCTAssertEqual(decoded.cpuCoreTemperatures.count, 24)
        XCTAssertEqual(decoded.controlMode, .fullControl)
    }

    func testCommandSignatureValidation() throws {
        var command = RemoteUDPFanCommand(
            deviceId: "device-1",
            timestamp: 1_779_753_600,
            nonce: "nonce-1",
            commandId: "command-1",
            command: .setSpeed,
            fanId: 0,
            speed: 2400
        )
        command.sign(sharedSecret: "secret")

        XCTAssertTrue(command.hasValidSignature(sharedSecret: "secret"))
        XCTAssertFalse(command.hasValidSignature(sharedSecret: "wrong-secret"))

        command.speed = 2600
        XCTAssertFalse(command.hasValidSignature(sharedSecret: "secret"))
    }

    func testCommandRejectsStaleTimestampAndReusedNonce() {
        let validator = RemoteUDPCommandValidator(
            sharedSecret: "secret",
            now: { 1000 },
            allowedClockSkew: 10
        )

        var command = RemoteUDPFanCommand(
            deviceId: "device-1",
            timestamp: 800,
            nonce: "nonce-1",
            commandId: "command-1",
            command: .reset
        )
        command.sign(sharedSecret: "secret")

        XCTAssertEqual(validator.validate(command), .rejected("stale command"))

        command.timestamp = 1000
        command.sign(sharedSecret: "secret")

        XCTAssertEqual(validator.validate(command), .accepted)
        XCTAssertEqual(validator.validate(command), .rejected("replayed command"))
    }

    func testCommandValidatorPrunesExpiredNoncesAndAllowsReuseAfterWindow() {
        var now = TimeInterval(1000)
        let validator = RemoteUDPCommandValidator(
            sharedSecret: "secret",
            now: { now },
            allowedClockSkew: 10,
            maxTrackedNonces: 32
        )

        XCTAssertEqual(validator.validate(self.command(timestamp: now, nonce: "nonce-1")), .accepted)
        XCTAssertEqual(validator.validate(self.command(timestamp: now, nonce: "nonce-1")), .rejected("replayed command"))

        now = 1015

        XCTAssertEqual(validator.validate(self.command(timestamp: now, nonce: "nonce-1")), .accepted)
        XCTAssertEqual(validator.trackedNonceCount, 1)
    }

    func testCommandValidatorEnforcesNonceCap() {
        var now = TimeInterval(1000)
        let validator = RemoteUDPCommandValidator(
            sharedSecret: "secret",
            now: { now },
            allowedClockSkew: 60,
            maxTrackedNonces: 3
        )

        for index in 0..<5 {
            now = 1000 + TimeInterval(index)
            XCTAssertEqual(validator.validate(self.command(timestamp: now, nonce: "nonce-\(index)")), .accepted)
        }

        XCTAssertEqual(validator.trackedNonceCount, 3)
    }

    func testFanSpeedValidationUsesMinAndMaxBounds() {
        let fan = RemoteUDPFanTelemetry(id: 0, name: "Left", rpm: 2100, minRpm: 1200, maxRpm: 5200, mode: .automatic)

        XCTAssertEqual(RemoteUDPFanCommand.validateSpeed(1200, for: fan), .accepted)
        XCTAssertEqual(RemoteUDPFanCommand.validateSpeed(5200, for: fan), .accepted)
        XCTAssertEqual(RemoteUDPFanCommand.validateSpeed(1199, for: fan), .rejected("speed below minimum"))
        XCTAssertEqual(RemoteUDPFanCommand.validateSpeed(5201, for: fan), .rejected("speed above maximum"))
    }

    func testDisplayFormatterUsesFreshestDeviceForMenuBarTextAndStack() {
        let old = RemoteUDPDeviceState(
            payload: RemoteUDPTelemetryPayload(
                deviceId: "old-device",
                deviceName: "Old",
                timestamp: 1,
                cpuTemperature: 40,
                gpuTemperature: 38,
                fans: [RemoteUDPFanTelemetry(id: 0, name: "Old fan", rpm: 1500, minRpm: 1000, maxRpm: 5000, mode: .automatic)]
            ),
            receivedAt: Date(timeIntervalSince1970: 1)
        )
        let fresh = RemoteUDPDeviceState(
            payload: RemoteUDPTelemetryPayload(
                deviceId: "fresh-device",
                deviceName: "Studio",
                timestamp: 2,
                cpuTemperature: 48.5,
                gpuTemperature: 43.2,
                cpuUsage: 0.42,
                gpuUsage: 0.36,
                cpuCoreTemperatures: [],
                gpuCoreTemperatures: [],
                cpuCoreUsages: [],
                gpuCoreUsages: [],
                fans: [RemoteUDPFanTelemetry(id: 1, name: "Main fan", rpm: 2100, minRpm: 1200, maxRpm: 5200, mode: .manual)]
            ),
            receivedAt: Date(timeIntervalSince1970: 2)
        )

        let options = RemoteUDPDisplayOptions()
        XCTAssertEqual(RemoteUDPDisplayFormatter.menuBarText([old, fresh], options: options), "Studio CPU 49° CPU 42% Main fan 2100rpm")
        let stackValues = RemoteUDPDisplayFormatter.stackValues([old, fresh], options: options)
        XCTAssertEqual(stackValues.map(\.value), ["Studio", "49°", "42%", "2100"])
        XCTAssertTrue(stackValues[0].singleRow)
        XCTAssertFalse(stackValues[1].singleRow)
    }

    func testDisplayFormatterUsesCustomNameAndSelectedMetrics() {
        let state = RemoteUDPDeviceState(payload: RemoteUDPTelemetryPayload(
            deviceId: "device-1",
            deviceName: "Studio",
            timestamp: 2,
            cpuTemperature: 48.5,
            gpuTemperature: 43.2,
            cpuUsage: 0.42,
            gpuUsage: 0.36,
            cpuCoreTemperatures: [RemoteUDPMetricTelemetry(id: "cpu-p0", name: "P-Core 0", value: 52.5, unit: "C")],
            gpuCoreTemperatures: [],
            cpuCoreUsages: [],
            gpuCoreUsages: [RemoteUDPMetricTelemetry(id: "gpu", name: "GPU", value: 0.36, unit: "%")],
            fans: [RemoteUDPFanTelemetry(id: 1, name: "Main fan", rpm: 2100, minRpm: 1200, maxRpm: 5200, mode: .manual)]
        ))

        let options = RemoteUDPDisplayOptions(
            displayName: "Desk Mac",
            showCPUTemperature: false,
            showCPUUsage: true,
            showGPUTemperature: true,
            showGPUUsage: false,
            showCPUCoreTemperatures: true,
            showGPUCoreTemperatures: false,
            showCPUCoreUsages: false,
            showGPUCoreUsages: true,
            showFanSpeed: false
        )

        XCTAssertEqual(
            RemoteUDPDisplayFormatter.menuBarText([state], options: options),
            "Desk Mac CPU 42% GPU 43° P-Core 0 53° GPU 36%"
        )
        XCTAssertEqual(
            RemoteUDPDisplayFormatter.stackValues([state], options: options).map(\.value),
            ["Desk Mac", "42%", "43°", "53°", "36%"]
        )
        XCTAssertTrue(RemoteUDPDisplayFormatter.stackValues([state], options: options)[0].singleRow)
    }

    func testDisplayFormatterDetailedSummaryIncludesCoreMetrics() {
        let state = RemoteUDPDeviceState(payload: RemoteUDPTelemetryPayload(
            deviceId: "device-1",
            deviceName: "Studio",
            timestamp: 2,
            cpuTemperature: 48.5,
            gpuTemperature: 43.2,
            cpuUsage: 0.42,
            gpuUsage: 0.36,
            cpuCoreTemperatures: [RemoteUDPMetricTelemetry(id: "cpu-p0", name: "P-Core 0", value: 52.5, unit: "C")],
            gpuCoreTemperatures: [RemoteUDPMetricTelemetry(id: "gpu-core", name: "GPU Core", value: 43.2, unit: "C")],
            cpuCoreUsages: [RemoteUDPMetricTelemetry(id: "cpu-0", name: "CPU Core 0", value: 0.42, unit: "%")],
            gpuCoreUsages: [RemoteUDPMetricTelemetry(id: "gpu", name: "GPU", value: 0.36, unit: "%")],
            fans: []
        ))

        let summary = RemoteUDPDisplayFormatter.detailedSummary(state)

        XCTAssertTrue(summary.contains("CPU 48.5 C / 42%"))
        XCTAssertTrue(summary.contains("P-Core 0 52.5C"))
        XCTAssertTrue(summary.contains("GPU 43.2 C / 36%"))
        XCTAssertTrue(summary.contains("GPU 36%"))
    }

    func testRemoteUDPReceivedDevicesPrunesExpiredState() {
        let remote = RemoteUDP(
            sender: RemoteUDPSender(),
            now: { Date(timeIntervalSince1970: 200) },
            deviceTTL: 60,
            maxTrackedDevices: 8
        )

        remote.debugSetDevices([
            "old": self.telemetryState(id: "old", name: "Old", receivedAt: 100),
            "fresh": self.telemetryState(id: "fresh", name: "Fresh", receivedAt: 180)
        ])

        XCTAssertEqual(remote.receivedDevices.map(\.payload.deviceId), ["fresh"])
        XCTAssertEqual(remote.deviceCount, 1)
    }

    func testRemoteUDPReceivedDevicesEvictsOldestWhenOverLimit() {
        let remote = RemoteUDP(
            sender: RemoteUDPSender(),
            now: { Date(timeIntervalSince1970: 300) },
            deviceTTL: 600,
            maxTrackedDevices: 2
        )

        remote.debugSetDevices([
            "one": self.telemetryState(id: "one", name: "One", receivedAt: 100),
            "two": self.telemetryState(id: "two", name: "Two", receivedAt: 200),
            "three": self.telemetryState(id: "three", name: "Three", receivedAt: 250)
        ])

        XCTAssertEqual(remote.receivedDevices.map(\.payload.deviceId), ["three", "two"])
        XCTAssertEqual(remote.deviceCount, 2)
    }

    func testRemoteUDPStopClearsRetainedState() {
        let remote = RemoteUDP(
            sender: RemoteUDPSender(),
            now: { Date(timeIntervalSince1970: 300) },
            deviceTTL: 600,
            maxTrackedDevices: 8
        )

        remote.debugSetDevices([
            "one": self.telemetryState(id: "one", name: "One", receivedAt: 250)
        ])
        remote.updateCPUUsage(total: 0.5, cores: [RemoteUDPMetricTelemetry(id: "cpu-0", name: "CPU", value: 0.5, unit: "%")])
        remote.updateGPUUsage(total: 0.25, cores: [RemoteUDPMetricTelemetry(id: "gpu-0", name: "GPU", value: 0.25, unit: "%")])

        remote.stop()

        XCTAssertEqual(remote.receivedDevices.count, 0)
        XCTAssertNil(remote.currentCPUUsage)
        XCTAssertNil(remote.currentGPUUsage)
        XCTAssertTrue(remote.currentCPUCoreUsages.isEmpty)
        XCTAssertTrue(remote.currentGPUCoreUsages.isEmpty)
    }

    func testUDPSenderAndReceiverDeliverTelemetryJSON() throws {
        let port = UInt16(Int.random(in: 40_000...50_000))
        let expectation = expectation(description: "telemetry received over UDP")
        let receiver = RemoteUDPReceiver(port: port) { data, _ in
            let decoded = try? JSONDecoder().decode(RemoteUDPTelemetryPayload.self, from: data)
            XCTAssertEqual(decoded?.deviceId, "device-udp")
            XCTAssertEqual(decoded?.fans.first?.rpm, 1800)
            expectation.fulfill()
        }
        try receiver.start()
        defer { receiver.stop() }

        let payload = RemoteUDPTelemetryPayload(
            deviceId: "device-udp",
            deviceName: "Loopback",
            timestamp: 1_779_753_600,
            cpuTemperature: 51.25,
            gpuTemperature: nil,
            fans: [
                RemoteUDPFanTelemetry(id: 0, name: "Main", rpm: 1800, minRpm: 1200, maxRpm: 5000, mode: .manual)
            ]
        )
        let data = try JSONEncoder().encode(payload)

        RemoteUDPSender().send(data, host: "127.0.0.1", port: port)

        wait(for: [expectation], timeout: 2)
    }

    func testUDPSenderReusesConnectionForRepeatedPacketsToSameEndpoint() throws {
        let port = UInt16(Int.random(in: 40_000...50_000))
        let sender = RemoteUDPSender()
        let expectation = expectation(description: "two telemetry packets received")
        expectation.expectedFulfillmentCount = 2

        var connectionCountAfterSecondPacket = 0
        var receiveCount = 0
        var receiver: RemoteUDPReceiver!
        receiver = RemoteUDPReceiver(port: port) { _, _ in
            receiveCount += 1
            if receiveCount == 2 {
                connectionCountAfterSecondPacket = Self.receiverConnectionCount(receiver)
            }
            expectation.fulfill()
        }
        try receiver.start()
        defer { receiver.stop() }

        let payload = RemoteUDPTelemetryPayload(
            deviceId: "device-udp",
            deviceName: "Loopback",
            timestamp: 1_779_753_600,
            cpuTemperature: 51.25,
            gpuTemperature: nil,
            fans: []
        )
        let data = try JSONEncoder().encode(payload)

        sender.send(data, host: "127.0.0.1", port: port)
        sender.send(data, host: "127.0.0.1", port: port)

        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(connectionCountAfterSecondPacket, 1)
    }

    func testUDPReceiverPrunesIdleConnections() throws {
        let port = UInt16(Int.random(in: 40_000...50_000))
        var now = Date(timeIntervalSince1970: 100)
        let expectation = expectation(description: "telemetry received over UDP")
        let receiver = RemoteUDPReceiver(
            port: port,
            now: { now },
            connectionIdleTTL: 5,
            handler: { _, _ in
                expectation.fulfill()
            }
        )
        try receiver.start()
        defer { receiver.stop() }

        let payload = RemoteUDPTelemetryPayload(
            deviceId: "device-udp",
            deviceName: "Loopback",
            timestamp: 1_779_753_600,
            cpuTemperature: 51.25,
            gpuTemperature: nil,
            fans: []
        )
        let data = try JSONEncoder().encode(payload)

        RemoteUDPSender().send(data, host: "127.0.0.1", port: port)

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(Self.receiverConnectionCount(receiver), 1)

        now = Date(timeIntervalSince1970: 110)
        receiver.debugPruneConnections()

        XCTAssertEqual(Self.receiverConnectionCount(receiver), 0)
    }
}
