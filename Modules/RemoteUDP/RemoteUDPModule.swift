//
//  RemoteUDPModule.swift
//  Stats
//
//  Created by Codex on 26/05/2026.
//

import Cocoa
import Kit

public final class RemoteUDPModule: Module {
    private let popupView = RemoteUDPPopup()
    private let settingsView = RemoteUDPSettings()
    private let renderQueue = DispatchQueue(label: "eu.exelban.Stats.RemoteUDP.ModuleRender")
    private let widgetListKey = "Remote UDP_widget"
    private let stackModeKey = "Remote UDP_\(widget_t.stack.rawValue)_mode"
    private let widgetMigrationKey = "RemoteUDP_widgetMigratedToStack_v1"
    private let stackModeMigrationKey = "RemoteUDP_stackModeMigrated_v1"
    private let autoStackMode = "auto"
    private let oneRowStackMode = "oneRow"
    private let twoRowsStackMode = "twoRows"
    private var pendingDevices: [RemoteUDPDeviceState] = []
    private var hasPendingRender = false
    private var isRenderScheduled = false

    public init() {
        super.init(
            moduleType: .remoteUDP,
            popup: self.popupView,
            settings: self.settingsView
        )

        guard self.available else { return }

        self.migrateWidgetSelectionIfNeeded()
        self.migrateStackModeIfNeeded()

        self.settingsView.callback = { [weak self] in
            RemoteUDP.shared.reload()
            self?.update(RemoteUDP.shared.receivedDevices)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleTelemetry),
            name: .remoteUDPTelemetry,
            object: nil
        )

        self.update(RemoteUDP.shared.receivedDevices)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .remoteUDPTelemetry, object: nil)
    }

    @objc private func handleTelemetry(_ notification: Notification) {
        self.update(RemoteUDP.shared.receivedDevices)
    }

    private func migrateWidgetSelectionIfNeeded() {
        guard !Store.shared.exist(key: self.widgetMigrationKey) else { return }

        let widgets = Store.shared.string(key: self.widgetListKey, defaultValue: widget_t.text.rawValue)
        if widgets == widget_t.text.rawValue {
            Store.shared.set(key: self.widgetListKey, value: widget_t.stack.rawValue)
        }

        Store.shared.set(key: self.widgetMigrationKey, value: true)
    }

    private func migrateStackModeIfNeeded() {
        guard !Store.shared.exist(key: self.stackModeMigrationKey) else { return }

        let mode = Store.shared.string(key: self.stackModeKey, defaultValue: self.autoStackMode)
        if mode == self.oneRowStackMode {
            Store.shared.set(key: self.stackModeKey, value: self.twoRowsStackMode)
        }

        Store.shared.set(key: self.stackModeMigrationKey, value: true)
    }

    private func update(_ devices: [RemoteUDPDeviceState]) {
        let shouldSchedule = self.renderQueue.sync { () -> Bool in
            self.pendingDevices = devices
            self.hasPendingRender = true
            guard !self.isRenderScheduled else { return false }
            self.isRenderScheduled = true
            return true
        }

        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingUpdate()
        }
    }

    private func flushPendingUpdate() {
        let devices = self.renderQueue.sync { () -> [RemoteUDPDeviceState] in
            self.hasPendingRender = false
            return self.pendingDevices
        }

        self.popupView.update(devices)

        self.menuBar.widgets.filter { $0.isActive }.forEach { widget in
            switch widget.item {
            case let widget as TextWidget:
                widget.setValue(RemoteUDPDisplayFormatter.menuBarText(devices))
            case let widget as StackWidget:
                widget.setValues(RemoteUDPDisplayFormatter.stackValues(devices))
            default:
                break
            }
        }

        let needsAnotherPass = self.renderQueue.sync { () -> Bool in
            if self.hasPendingRender {
                return true
            }
            self.isRenderScheduled = false
            return false
        }

        guard needsAnotherPass else { return }
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingUpdate()
        }
    }
}
