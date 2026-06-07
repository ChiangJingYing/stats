//
//  settings.swift
//  Stats
//
//  Created by Codex on 26/05/2026.
//

import Cocoa
import Kit

final class RemoteUDPSettings: NSStackView, Settings_v, NSTextFieldDelegate {
    var callback: (() -> Void)?

    private let receiveTelemetryKey = "RemoteUDP_receiveTelemetry"
    private let telemetryListenPortKey = "RemoteUDP_telemetryListenPort"
    private let commandTargetPortKey = "RemoteUDP_commandTargetPort"
    private let sharedSecretKey = "RemoteUDP_sharedSecret"
    private let displayNameKey = "RemoteUDP_displayName"
    private let displayKeys: [(key: String, title: String, defaultValue: Bool)] = [
        ("RemoteUDP_display_cpuTemperature", "CPU temperature", true),
        ("RemoteUDP_display_cpuUsage", "CPU usage", true),
        ("RemoteUDP_display_gpuTemperature", "GPU temperature", false),
        ("RemoteUDP_display_gpuUsage", "GPU usage", false),
        ("RemoteUDP_display_cpuCoreTemperatures", "CPU core temperatures", false),
        ("RemoteUDP_display_cpuCoreUsages", "CPU core usage", false),
        ("RemoteUDP_display_gpuCoreTemperatures", "GPU core temperatures", false),
        ("RemoteUDP_display_gpuCoreUsages", "GPU core usage", false),
        ("RemoteUDP_display_fanSpeed", "Fan speed", true)
    ]

    init() {
        super.init(frame: .zero)

        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.spacing = Constants.Settings.margin
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func load(widgets: [widget_t]) {
        self.subviews.forEach { $0.removeFromSuperview() }

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Receive telemetry"), component: switchView(
                action: #selector(self.toggleReceiveTelemetry),
                state: Store.shared.bool(key: self.receiveTelemetryKey, defaultValue: false)
            )),
            PreferencesRow(localizedString("Telemetry listen port"), component: self.inputField(
                id: self.telemetryListenPortKey,
                value: "\(Store.shared.int(key: self.telemetryListenPortKey, defaultValue: 7530))",
                placeholder: "7530"
            )),
            PreferencesRow(localizedString("Command target port"), component: self.inputField(
                id: self.commandTargetPortKey,
                value: "\(Store.shared.int(key: self.commandTargetPortKey, defaultValue: 7531))",
                placeholder: "7531"
            )),
            PreferencesRow(localizedString("Shared secret"), component: self.inputField(
                id: self.sharedSecretKey,
                value: Store.shared.string(key: self.sharedSecretKey, defaultValue: ""),
                placeholder: localizedString("Required for fan control"),
                secure: true
            ))
        ]))

        var displayRows: [PreferencesRow] = [
            PreferencesRow(localizedString("Device name"), component: self.inputField(
                id: self.displayNameKey,
                value: Store.shared.string(key: self.displayNameKey, defaultValue: ""),
                placeholder: localizedString("Use received name")
            ))
        ]
        self.displayKeys.forEach { item in
            displayRows.append(PreferencesRow(localizedString(item.title), component: self.displaySwitch(
                key: item.key,
                defaultValue: item.defaultValue
            )))
        }
        self.addArrangedSubview(PreferencesSection(title: localizedString("Menu bar"), displayRows))
    }

    @objc private func toggleReceiveTelemetry(_ sender: NSButton) {
        Store.shared.set(key: self.receiveTelemetryKey, value: sender.state == .on)
        self.callback?()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              let identifier = field.identifier?.rawValue,
              [self.telemetryListenPortKey, self.commandTargetPortKey, self.sharedSecretKey, self.displayNameKey].contains(identifier) else { return }

        if identifier.hasSuffix("Port") {
            let filtered = field.stringValue.filter { "0123456789".contains($0) }
            if filtered != field.stringValue {
                field.stringValue = filtered
            }
            guard let port = Int(field.stringValue), port > 0, port <= 65_535 else { return }
            Store.shared.set(key: identifier, value: port)
            if identifier == self.telemetryListenPortKey {
                self.callback?()
            }
        } else {
            Store.shared.set(key: identifier, value: field.stringValue)
            self.callback?()
        }
    }

    @objc private func toggleDisplayItem(_ sender: NSControl) {
        guard let key = sender.identifier?.rawValue else { return }
        Store.shared.set(key: key, value: controlState(sender))
        self.callback?()
    }

    private func inputField(id: String, value: String, placeholder: String, secure: Bool = false) -> NSTextField {
        let field: NSTextField = secure ? NSSecureTextField() : NSTextField()
        field.identifier = NSUserInterfaceItemIdentifier(id)
        field.widthAnchor.constraint(equalToConstant: 150).isActive = true
        field.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        field.textColor = .textColor
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.focusRingType = .none
        field.stringValue = value
        field.delegate = self
        field.placeholderString = placeholder
        return field
    }

    private func displaySwitch(key: String, defaultValue: Bool) -> NSView {
        let view = switchView(
            action: #selector(self.toggleDisplayItem),
            state: Store.shared.bool(key: key, defaultValue: defaultValue)
        )
        view.identifier = NSUserInterfaceItemIdentifier(key)
        return view
    }
}
