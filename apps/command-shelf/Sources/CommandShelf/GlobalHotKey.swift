import Foundation
import Carbon.HIToolbox

@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    static let signature: OSType = 0x53594C50  // 'SYLP'
    static let identifier: UInt32 = 1

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        unregister()
        self.handler = handler

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard registerStatus == noErr, let ref else { return false }
        self.hotKeyRef = ref

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var handlerRef: EventHandlerRef?
        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var receivedID = EventHotKeyID()
                let paramStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedID
                )
                guard paramStatus == noErr else { return paramStatus }
                guard receivedID.signature == GlobalHotKey.signature,
                      receivedID.id == GlobalHotKey.identifier
                else { return noErr }

                let target = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    target.handler?()
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &handlerRef
        )
        guard handlerStatus == noErr else {
            UnregisterEventHotKey(ref)
            self.hotKeyRef = nil
            return false
        }
        self.eventHandlerRef = handlerRef
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        handler = nil
    }
}

enum PaletteHotKey {
    /// ⌥ Space — the launcher summoning chord.
    static let keyCode: UInt32 = UInt32(kVK_Space)
    static let modifiers: UInt32 = UInt32(optionKey)
}
