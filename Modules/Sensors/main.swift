//
//  main.swift
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 17/06/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Sensors: Module {
    private var sensorsReader: SensorsReader?
    private let popupView: Popup
    private let settingsView: Settings
    private let portalView: Portal
    private let notificationsView: Notifications
    
    private var fanValueState: FanValue {
        FanValue(rawValue: Store.shared.string(key: "\(self.config.name)_fanValue", defaultValue: "percentage")) ?? .percentage
    }
    
    private var selectedSensor: String
    
    public init() {
        self.settingsView = Settings(.sensors)
        self.popupView = Popup()
        self.portalView = Portal(.sensors)
        self.notificationsView = Notifications(.sensors)
        self.selectedSensor = Store.shared.string(key: "\(ModuleType.sensors.stringValue)_sensor", defaultValue: "Average System Total")
        
        super.init(
            moduleType: .sensors,
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView,
            notifications: self.notificationsView
        )
        guard self.available else { return }
        
        self.sensorsReader = SensorsReader { [weak self] value in
            self?.usageCallback(value)
        }
        
        self.settingsView.setList(self.sensorsReader?.list.sensors)
        self.popupView.setup(self.sensorsReader?.list.sensors)
        self.portalView.setup(self.sensorsReader?.list.sensors)
        self.notificationsView.setup(self.sensorsReader?.list.sensors)
        
        self.settingsView.callback = { [weak self] in
            self?.sensorsReader?.read()
        }
        self.settingsView.setInterval = { [weak self] value in
            self?.sensorsReader?.setInterval(value)
        }
        self.settingsView.HIDcallback = { [weak self] in
            DispatchQueue.global(qos: .background).async {
                self?.sensorsReader?.HIDCallback()
                DispatchQueue.main.async {
                    self?.popupView.setup(self?.sensorsReader?.list.sensors)
                    self?.portalView.setup(self?.sensorsReader?.list.sensors)
                    self?.settingsView.setList(self?.sensorsReader?.list.sensors)
                    self?.notificationsView.setup(self?.sensorsReader?.list.sensors)
                }
            }
        }
        self.settingsView.unknownCallback = { [weak self] in
            DispatchQueue.global(qos: .background).async {
                self?.sensorsReader?.unknownCallback()
                DispatchQueue.main.async {
                    self?.popupView.setup(self?.sensorsReader?.list.sensors)
                    self?.portalView.setup(self?.sensorsReader?.list.sensors)
                    self?.settingsView.setList(self?.sensorsReader?.list.sensors)
                    self?.notificationsView.setup(self?.sensorsReader?.list.sensors)
                }
            }
        }
        self.selectedSensor = Store.shared.string(key: "\(ModuleType.sensors.stringValue)_sensor", defaultValue: self.selectedSensor)
        self.settingsView.selectedHandler = { [weak self] value in
            self?.selectedSensor = value
            self?.sensorsReader?.read()
        }
        RemoteUDP.shared.fanCommandHandler = { [weak self] command in
            self?.handleRemoteFanCommand(command) ?? RemoteUDPFanCommandAck(
                deviceId: command.deviceId,
                commandId: command.commandId,
                status: .failed,
                message: "sensors module unavailable"
            )
        }
        RemoteUDP.shared.reload()
        
        self.setReaders([self.sensorsReader])
    }
    
    public override func willTerminate() {
        guard SMCHelper.shared.isActive(), let reader = self.sensorsReader else { return }
        
        reader.list.sensors.filter({ $0 is Fan }).forEach { (s: Sensor_p) in
            if let f = s as? Fan, let mode = f.customMode {
                if !mode.isAutomatic {
                    SMCHelper.shared.setFanMode(f.id, mode: FanMode.automatic.rawValue)
                }
            }
        }
    }
    
    private func usageCallback(_ raw: Sensors_List?) {
        guard let value = raw, self.enabled else { return }
        
        self.popupView.usageCallback(value.sensors)
        self.portalView.usageCallback(value.sensors)
        self.notificationsView.usageCallback(value.sensors)
        RemoteUDP.shared.sendTelemetry(self.remoteTelemetry(from: value.sensors))
        
        let activeWidgets = self.menuBar.widgets.filter{ $0.isActive }
        self.sensorsReader?.sleepMode(state: activeWidgets.contains(where: {$0.item is Label}) && activeWidgets.count == 1)
        
        activeWidgets.forEach { (w: SWidget) in
            switch w.item {
            case let widget as Mini:
                if let active = value.sensors.first(where: { $0.key == self.selectedSensor }) {
                    var value: Double = active.localValue/100
                    var unit: String = active.miniUnit
                    if let fan = active as? Fan, self.fanValueState == .percentage {
                        value = Double(fan.percentage)/100
                        unit = "%"
                    }
                    if value > 999 {
                        unit = ""
                    }
                    widget.setValue(value)
                    widget.setSuffix(unit)
                }
            case let widget as StackWidget:
                var list: [Stack_t] = []
                
                value.sensors.forEach { (s: Sensor_p) in
                    if s.state {
                        var value = s.formattedMiniValue
                        if let f = s as? Fan {
                            if self.fanValueState == .percentage {
                                value = "\(f.percentage)%"
                            }
                        }
                        list.append(Stack_t(key: s.key, value: value))
                    }
                }
                
                widget.setValues(list)
            case let widget as BarChart:
                var flatList: [[ColorValue]] = []
                value.sensors.filter{ $0 is Fan }.forEach { (s: Sensor_p) in
                    if s.state, let f = s as? Fan {
                        flatList.append([ColorValue(((f.value*100)/f.maxSpeed)/100)])
                    }
                }
                widget.setValue(flatList)
            default: break
            }
        }
    }

    private func remoteTelemetry(from sensors: [Sensor_p]) -> RemoteUDPTelemetryPayload {
        let commandChannelAvailable = Store.shared.bool(key: "RemoteUDP_receiveCommands", defaultValue: false)
        let helperInstalled = SMCHelper.shared.isInstalled
        let helperAvailable = SMCHelper.shared.isAvailable(timeout: 0.2, quiet: true)
        let controlMode: RemoteUDPControlMode = (commandChannelAvailable && helperAvailable) ? .fullControl : .monitorOnly
        let fans: [RemoteUDPFanTelemetry] = sensors.compactMap { sensor in
            guard let fan = sensor as? Fan, !fan.isComputed else { return nil }
            return RemoteUDPFanTelemetry(
                id: fan.id,
                name: fan.name,
                rpm: Int(fan.value),
                minRpm: Int(fan.minSpeed),
                maxRpm: Int(fan.maxSpeed),
                mode: fan.mode.isAutomatic ? .automatic : .manual
            )
        }
        return RemoteUDPTelemetryPayload(
            deviceId: self.remoteDeviceId,
            deviceName: Host.current().localizedName ?? SystemKit.shared.device.model.name,
            timestamp: Date().timeIntervalSince1970,
            cpuTemperature: self.averageTemperature(in: sensors, group: .CPU),
            gpuTemperature: self.averageTemperature(in: sensors, group: .GPU),
            cpuUsage: RemoteUDP.shared.currentCPUUsage,
            gpuUsage: RemoteUDP.shared.currentGPUUsage,
            cpuCoreTemperatures: self.temperatureMetrics(in: sensors, group: .CPU, prefix: "cpu-temp"),
            gpuCoreTemperatures: self.temperatureMetrics(in: sensors, group: .GPU, prefix: "gpu-temp"),
            cpuCoreUsages: RemoteUDP.shared.currentCPUCoreUsages,
            gpuCoreUsages: RemoteUDP.shared.currentGPUCoreUsages,
            fans: fans,
            fanControlAvailable: helperAvailable,
            commandChannelAvailable: commandChannelAvailable,
            controlMode: controlMode,
            controlProvider: "app-proxy-smc-helper",
            helperIdentifier: helperInstalled ? "eu.exelban.Stats.SMC.Helper" : nil
        )
    }

    private var remoteDeviceId: String {
        if let serial = SystemKit.shared.device.serialNumber, !serial.isEmpty {
            return serial
        }
        let key = "RemoteUDP_deviceId"
        let stored = Store.shared.string(key: key, defaultValue: "")
        if !stored.isEmpty {
            return stored
        }
        let id = UUID().uuidString
        Store.shared.set(key: key, value: id)
        return id
    }

    private func averageTemperature(in sensors: [Sensor_p], group: SensorGroup) -> Double? {
        if let average = sensors.first(where: { $0.group == group && $0.type == .temperature && $0.isComputed && $0.key.hasPrefix("Average") }) {
            return average.value
        }
        let values = sensors.filter { $0.group == group && $0.type == .temperature && !$0.isComputed }.map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func temperatureMetrics(in sensors: [Sensor_p], group: SensorGroup, prefix: String) -> [RemoteUDPMetricTelemetry] {
        sensors
            .filter { $0.group == group && $0.type == .temperature && !$0.isComputed }
            .map {
                RemoteUDPMetricTelemetry(
                    id: "\(prefix)-\($0.key)",
                    name: $0.name,
                    value: $0.value,
                    unit: "C"
                )
            }
    }

    private func handleRemoteFanCommand(_ command: RemoteUDPFanCommand) -> RemoteUDPFanCommandAck {
        guard SMCHelper.shared.isInstalled else {
            return self.remoteFanAck(command, status: .failed, message: "fan helper not installed")
        }
        guard SMCHelper.shared.isAvailable() else {
            return self.remoteFanAck(command, status: .failed, message: "fan helper unavailable")
        }

        let fans = self.sensorsReader?.list.sensors.compactMap { $0 as? Fan }.filter { !$0.isComputed } ?? []
        switch command.command {
        case .reset:
            guard SMCHelper.shared.resetFanControl() else {
                return self.remoteFanAck(command, status: .failed, message: "fan helper unavailable")
            }
            fans.forEach { fan in
                var updated = fan
                updated.customMode = nil
                updated.customSpeed = nil
            }
            return self.remoteFanAck(command, status: .ok, message: "fan control reset")
        case .setModeAuto, .setModeManual, .setSpeed:
            guard let fanId = command.fanId, var fan = fans.first(where: { $0.id == fanId }) else {
                return self.remoteFanAck(command, status: .rejected, message: "fan not found")
            }

            if command.command == .setSpeed {
                guard let speed = command.speed else {
                    return self.remoteFanAck(command, status: .rejected, message: "missing speed")
                }
                let telemetry = RemoteUDPFanTelemetry(
                    id: fan.id,
                    name: fan.name,
                    rpm: Int(fan.value),
                    minRpm: Int(fan.minSpeed),
                    maxRpm: Int(fan.maxSpeed),
                    mode: fan.mode.isAutomatic ? .automatic : .manual
                )
                if case let .rejected(reason) = RemoteUDPFanCommand.validateSpeed(speed, for: telemetry) {
                    return self.remoteFanAck(command, status: .rejected, message: reason)
                }
                if fan.mode != .forced {
                    guard SMCHelper.shared.setFanMode(fan.id, mode: FanMode.forced.rawValue) else {
                        return self.remoteFanAck(command, status: .failed, message: "fan helper unavailable")
                    }
                    fan.customMode = .forced
                }
                guard SMCHelper.shared.setFanSpeed(fan.id, speed: speed) else {
                    return self.remoteFanAck(command, status: .failed, message: "fan helper unavailable")
                }
                fan.customSpeed = speed
                return self.remoteFanAck(command, status: .ok, message: "fan speed set")
            }

            let mode: FanMode = command.command == .setModeAuto ? .automatic : .forced
            guard SMCHelper.shared.setFanMode(fan.id, mode: mode.rawValue) else {
                return self.remoteFanAck(command, status: .failed, message: "fan helper unavailable")
            }
            fan.customMode = mode.isAutomatic ? nil : mode
            if mode.isAutomatic {
                fan.customSpeed = nil
            }
            return self.remoteFanAck(command, status: .ok, message: "fan mode set")
        }
    }

    private func remoteFanAck(_ command: RemoteUDPFanCommand, status: RemoteUDPFanCommandAck.Status, message: String) -> RemoteUDPFanCommandAck {
        RemoteUDPFanCommandAck(deviceId: self.remoteDeviceId, commandId: command.commandId, status: status, message: message)
    }
}
