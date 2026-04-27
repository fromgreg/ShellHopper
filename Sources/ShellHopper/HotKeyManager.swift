import AppKit
import Carbon.HIToolbox

/// Registers global hotkeys via the Carbon RegisterEventHotKey API.
/// This is the same approach used by Alfred, Raycast, Rectangle, etc.,
/// and crucially it does NOT require Accessibility permission to listen
/// for keys — registration is granted by the OS to any running process.
final class HotKeyManager: ObservableObject {
    private struct Registration {
        let hotKeyRef: EventHotKeyRef?
        let handler: () -> Void
    }

    private var registrations: [String: Registration] = [:]
    private var nextID: UInt32 = 1
    private var idToKey: [UInt32: String] = [:]
    private var eventHandler: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()
        if let h = eventHandler { RemoveEventHandler(h) }
    }

    func register(id: String, shortcut: Shortcut, handler: @escaping () -> Void) {
        unregister(id: id)

        let hotKeyID = EventHotKeyID(signature: OSType(0x534C4850 /* "SLHP" */),
                                     id: nextID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers(from: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            NSLog("ShellHopper: failed to register hotkey for \(id), OSStatus=\(status)")
            return
        }

        idToKey[nextID] = id
        registrations[id] = Registration(hotKeyRef: ref, handler: handler)
        nextID &+= 1
    }

    func unregister(id: String) {
        if let r = registrations[id], let ref = r.hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        registrations.removeValue(forKey: id)
        // Note: we leave idToKey entries; they're harmless and IDs aren't reused.
    }

    func unregisterAll() {
        for (id, _) in registrations { unregister(id: id) }
        registrations.removeAll()
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(eventRef,
                                            EventParamName(kEventParamDirectObject),
                                            EventParamType(typeEventHotKeyID),
                                            nil,
                                            MemoryLayout<EventHotKeyID>.size,
                                            nil,
                                            &hotKeyID)
                guard err == noErr else { return err }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                if let key = manager.idToKey[hotKeyID.id],
                   let reg = manager.registrations[key] {
                    DispatchQueue.main.async { reg.handler() }
                }
                return noErr
            },
            1,
            &spec,
            userData,
            &eventHandler
        )
    }

    /// Translate NSEvent.ModifierFlags raw value into Carbon modifier mask.
    private func carbonModifiers(from rawNSFlags: UInt32) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawNSFlags))
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }
}
