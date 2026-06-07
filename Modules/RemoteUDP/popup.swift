//
//  popup.swift
//  Stats
//
//  Created by Codex on 26/05/2026.
//

import Cocoa
import Kit

final class RemoteUDPPopup: PopupWrapper {
    private let emptyView = NSTextField(labelWithString: localizedString("No devices"))
    private let contentWidth = Constants.Popup.width
    private let devicesCache = PopupCache<[RemoteUDPDeviceState]>()
    private var deviceViews: [String: RemoteUDPDeviceView] = [:]

    init() {
        super.init(.remoteUDP, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 34))

        self.orientation = .vertical
        self.spacing = 0
        self.emptyView.alignment = .center
        self.addArrangedSubview(self.emptyView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ devices: [RemoteUDPDeviceState]) {
        let applyUpdate = {
            self.devicesCache.apply(devices, visible: self.window?.isVisible ?? false, render: self.render)
        }

        if Thread.isMainThread {
            applyUpdate()
        } else {
            DispatchQueue.main.async(execute: applyUpdate)
        }
    }

    override func appear() {
        self.replay(self.devicesCache, render: self.render)
    }

    private func render(_ devices: [RemoteUDPDeviceState]) {
        if devices.isEmpty {
            self.deviceViews.values.forEach {
                self.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }
            self.deviceViews.removeAll()
            if self.emptyView.superview == nil {
                self.addArrangedSubview(self.emptyView)
            }
            self.recalculateHeight()
            return
        }

        self.emptyView.removeFromSuperview()

        let ids = Set(devices.map { $0.payload.deviceId })
        self.deviceViews.keys.filter { !ids.contains($0) }.forEach { id in
            self.deviceViews[id]?.removeFromSuperview()
            self.deviceViews.removeValue(forKey: id)
        }

        devices.sorted { $0.payload.deviceName < $1.payload.deviceName }.forEach { state in
            let id = state.payload.deviceId
            if let view = self.deviceViews[id] {
                view.update(state)
            } else {
                let view = RemoteUDPDeviceView(width: self.contentWidth, state: state) { [weak self] in
                    self?.recalculateHeight()
                }
                self.deviceViews[id] = view
                self.addArrangedSubview(view)
            }
        }

        self.recalculateHeight()
    }

    private func recalculateHeight() {
        self.layoutSubtreeIfNeeded()
        let height = max(34, self.fittingSize.height)
        if abs(self.frame.height - height) > 1 {
            self.setFrameSize(NSSize(width: self.contentWidth, height: height))
            self.sizeCallback?(self.frame.size)
        }
    }
}

private final class RemoteUDPDeviceView: NSStackView {
    private let contentWidth: CGFloat
    private let sizeCallback: () -> Void
    private let titleField = NSTextField(labelWithString: "")
    private let lastSeenField = NSTextField(labelWithString: "")
    private var fanViews: [Int: RemoteUDPFanView] = [:]

    init(width: CGFloat, state: RemoteUDPDeviceState, sizeCallback: @escaping () -> Void) {
        self.contentWidth = width
        self.sizeCallback = sizeCallback
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))

        self.orientation = .vertical
        self.spacing = 0
        self.translatesAutoresizingMaskIntoConstraints = false
        self.titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        self.lastSeenField.font = .systemFont(ofSize: 10, weight: .regular)
        self.lastSeenField.textColor = .secondaryLabelColor

        self.update(state)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ state: RemoteUDPDeviceState) {
        self.arrangedSubviews.forEach {
            self.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        self.addArrangedSubview(self.header(state))

        let payload = state.payload
        if !payload.fans.isEmpty {
            self.addArrangedSubview(separatorView(localizedString("Fans"), width: self.contentWidth))
            payload.fans.forEach { fan in
                let view = self.fanViews[fan.id] ?? RemoteUDPFanView(
                    width: self.contentWidth,
                    deviceId: payload.deviceId,
                    sourceHost: state.sourceHost,
                    controlMode: payload.controlMode,
                    fanControlAvailable: payload.fanControlAvailable,
                    fan: fan,
                    sizeCallback: self.resize
                )
                view.update(
                    deviceId: payload.deviceId,
                    sourceHost: state.sourceHost,
                    controlMode: payload.controlMode,
                    fanControlAvailable: payload.fanControlAvailable,
                    fan: fan
                )
                self.fanViews[fan.id] = view
                self.addArrangedSubview(view)
            }
        }

        self.addMetrics(title: "CPU Temperature", metrics: payload.cpuCoreTemperatures)
        self.addMetrics(title: "CPU Usage", metrics: payload.cpuCoreUsages, percentage: true)
        self.addMetrics(title: "GPU Temperature", metrics: payload.gpuCoreTemperatures)
        self.addMetrics(title: "GPU Usage", metrics: payload.gpuCoreUsages, percentage: true)

        self.resize()
    }

    private func header(_ state: RemoteUDPDeviceState) -> NSView {
        let view = NSStackView(frame: NSRect(x: 0, y: 0, width: self.contentWidth, height: 30))
        view.widthAnchor.constraint(equalToConstant: self.contentWidth).isActive = true
        view.orientation = .vertical
        view.spacing = 1
        view.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)

        self.titleField.stringValue = state.payload.deviceName
        self.lastSeenField.stringValue = "Last seen \(Int(Date().timeIntervalSince(state.receivedAt)))s ago"

        view.addArrangedSubview(self.titleField)
        view.addArrangedSubview(self.lastSeenField)
        return view
    }

    private func addMetrics(title: String, metrics: [RemoteUDPMetricTelemetry], percentage: Bool = false) {
        guard !metrics.isEmpty else { return }
        self.addArrangedSubview(separatorView(localizedString(title), width: self.contentWidth))
        metrics.forEach { metric in
            self.addArrangedSubview(RemoteUDPMetricRow(width: self.contentWidth, metric: metric, percentage: percentage))
        }
    }

    private func resize() {
        self.layoutSubtreeIfNeeded()
        let height = self.fittingSize.height
        if abs(self.frame.height - height) > 1 {
            self.setFrameSize(NSSize(width: self.contentWidth, height: max(34, height)))
            self.sizeCallback()
        }
    }
}

private final class RemoteUDPMetricRow: NSStackView {
    private let valueField = NSTextField(labelWithString: "")

    init(width: CGFloat, metric: RemoteUDPMetricTelemetry, percentage: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))

        self.widthAnchor.constraint(equalToConstant: width).isActive = true
        self.heightAnchor.constraint(equalToConstant: 22).isActive = true
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.spacing = 0

        let nameField = LabelField(frame: .zero)
        nameField.stringValue = metric.name
        nameField.toolTip = metric.id
        nameField.cell?.truncatesLastVisibleLine = true

        self.valueField.alignment = .right
        self.valueField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        if percentage {
            self.valueField.stringValue = "\(Int((metric.value * 100).rounded()))%"
        } else {
            self.valueField.stringValue = String(format: "%.1f%@", metric.value, metric.unit)
        }

        self.addArrangedSubview(nameField)
        self.addArrangedSubview(self.valueField)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class RemoteUDPFanView: NSStackView {
    private let sizeCallback: () -> Void
    private var deviceId: String
    private var sourceHost: String?
    private var controlMode: RemoteUDPControlMode
    private var fanControlAvailable: Bool?
    private var fan: RemoteUDPFanTelemetry
    private let valueField = NSTextField(labelWithString: "")
    private let minValueField = NSTextField(labelWithString: "")
    private let maxValueField = NSTextField(labelWithString: "")
    private let slider: NSSlider
    private var buttons: [NSButton] = []
    private var debouncer: DispatchWorkItem?

    init(
        width: CGFloat,
        deviceId: String,
        sourceHost: String?,
        controlMode: RemoteUDPControlMode,
        fanControlAvailable: Bool?,
        fan: RemoteUDPFanTelemetry,
        sizeCallback: @escaping () -> Void
    ) {
        self.deviceId = deviceId
        self.sourceHost = sourceHost
        self.controlMode = controlMode
        self.fanControlAvailable = fanControlAvailable
        self.fan = fan
        self.sizeCallback = sizeCallback
        self.slider = NSSlider(value: Double(fan.rpm), minValue: Double(fan.minRpm), maxValue: Double(fan.maxRpm), target: nil, action: nil)

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))

        self.widthAnchor.constraint(equalToConstant: width).isActive = true
        self.orientation = .vertical
        self.spacing = 2
        self.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)

        self.addArrangedSubview(self.header(width: width))
        self.addArrangedSubview(self.controls(width: width))
        self.addArrangedSubview(self.sliderRow(width: width))
        self.update(deviceId: deviceId, sourceHost: sourceHost, controlMode: controlMode, fanControlAvailable: fanControlAvailable, fan: fan)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(deviceId: String, sourceHost: String?, controlMode: RemoteUDPControlMode, fanControlAvailable: Bool?, fan: RemoteUDPFanTelemetry) {
        self.deviceId = deviceId
        self.sourceHost = sourceHost
        self.controlMode = controlMode
        self.fanControlAvailable = fanControlAvailable
        self.fan = fan
        self.valueField.stringValue = "\(fan.rpm) RPM \(fan.mode.rawValue.capitalized)"
        self.updateControlState()
        self.slider.doubleValue = Double(fan.rpm)
        self.slider.minValue = Double(fan.minRpm)
        self.slider.maxValue = Double(fan.maxRpm)
        self.minValueField.stringValue = "\(fan.minRpm)"
        self.maxValueField.stringValue = "\(fan.maxRpm)"
    }

    private func header(width: CGFloat) -> NSView {
        let row = NSStackView(frame: NSRect(x: 0, y: 0, width: width - 12, height: 18))
        row.widthAnchor.constraint(equalToConstant: width - 12).isActive = true
        row.heightAnchor.constraint(equalToConstant: 18).isActive = true
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 0

        let nameField = LabelField(frame: .zero)
        nameField.stringValue = self.fan.name
        nameField.toolTip = "Fan \(self.fan.id)"

        self.valueField.alignment = .right
        self.valueField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        row.addArrangedSubview(nameField)
        row.addArrangedSubview(self.valueField)
        return row
    }

    private func controls(width: CGFloat) -> NSView {
        let row = NSStackView(frame: NSRect(x: 0, y: 0, width: width - 12, height: 22))
        row.widthAnchor.constraint(equalToConstant: width - 12).isActive = true
        row.heightAnchor.constraint(equalToConstant: 22).isActive = true
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.spacing = 4

        row.addArrangedSubview(self.button("Auto", action: #selector(self.setAuto)))
        row.addArrangedSubview(self.button("Manual", action: #selector(self.setManual)))
        row.addArrangedSubview(self.button("Reset", action: #selector(self.reset)))
        return row
    }

    private func sliderRow(width: CGFloat) -> NSView {
        let container = NSStackView(frame: NSRect(x: 0, y: 0, width: width - 12, height: 24))
        container.widthAnchor.constraint(equalToConstant: width - 12).isActive = true
        container.heightAnchor.constraint(equalToConstant: 24).isActive = true
        container.orientation = .horizontal
        container.spacing = 4

        self.slider.isContinuous = true
        self.slider.target = self
        self.slider.action = #selector(self.sliderChanged)
        self.slider.minValue = Double(self.fan.minRpm)
        self.slider.maxValue = Double(self.fan.maxRpm)
        self.slider.controlSize = .small

        self.minValueField.alignment = .left
        self.minValueField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        self.minValueField.textColor = .secondaryLabelColor
        self.minValueField.widthAnchor.constraint(equalToConstant: 44).isActive = true
        self.maxValueField.alignment = .right
        self.maxValueField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        self.maxValueField.textColor = .secondaryLabelColor
        self.maxValueField.widthAnchor.constraint(equalToConstant: 44).isActive = true
        self.slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.slider.setContentHuggingPriority(.defaultLow, for: .horizontal)

        container.addArrangedSubview(self.minValueField)
        container.addArrangedSubview(self.slider)
        container.addArrangedSubview(self.maxValueField)
        return container
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: localizedString(title), target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 11)
        button.focusRingType = .none
        self.buttons.append(button)
        return button
    }

    private func updateControlState() {
        let enabled = self.controlMode.supportsControl && self.fanControlAvailable != false
        self.buttons.forEach { $0.isEnabled = enabled }
        self.slider.isEnabled = enabled
    }

    @objc private func setAuto() {
        self.send(.setModeAuto)
    }

    @objc private func setManual() {
        self.send(.setModeManual)
    }

    @objc private func reset() {
        self.send(.reset, fanId: nil)
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        self.setSpeed(Int(sender.doubleValue))
    }

    private func setSpeed(_ speed: Int) {
        let bounded = min(max(speed, self.fan.minRpm), self.fan.maxRpm)
        self.slider.doubleValue = Double(bounded)
        self.debouncer?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.send(.setSpeed, speed: bounded)
        }
        self.debouncer = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func send(_ command: RemoteUDPFanCommandType, fanId: Int? = nil, speed: Int? = nil) {
        guard !Store.shared.string(key: "RemoteUDP_sharedSecret", defaultValue: "").isEmpty else { return }
        guard self.controlMode.supportsControl else { return }
        guard self.fanControlAvailable != false else { return }
        RemoteUDP.shared.sendFanCommand(
            deviceId: self.deviceId,
            command: command,
            fanId: fanId ?? self.fan.id,
            speed: speed,
            host: self.sourceHost
        )
    }
}
