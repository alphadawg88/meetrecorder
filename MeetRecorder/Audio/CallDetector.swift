import CoreAudio
import Foundation

/// Detects when *any* app starts using the default input device (the microphone),
/// app-agnostic across Teams / Zoom / Meet / FaceTime / Slack huddles. It listens
/// to the public CoreAudio property `kAudioDevicePropertyDeviceIsRunningSomewhere`,
/// so there is no fragile per-app process-name matching.
///
/// When the mic goes active and stays active past a short debounce window — and
/// Glyph isn't already recording — it invokes `onCallLikelyStarted` so the app can
/// offer to record. It fires at most once per continuous mic session and resets
/// when the mic is released (the call ends).
///
/// Note: this property is true whenever the mic is in use, *including Glyph's own
/// recording*. We never prompt while Glyph is busy (see the `isBusy` gate), so our
/// own capture doesn't trigger a self-prompt.
@MainActor
final class CallDetector: ObservableObject {
    /// Fired once when a call is likely in progress (mic active past the debounce,
    /// and `isBusy` returned false). The app decides whether to surface a prompt.
    var onCallLikelyStarted: (() -> Void)?
    /// Queried just before prompting. Return true if Glyph is already recording or
    /// processing — that suppresses the prompt (our own mic use is not a "call").
    var isBusy: (() -> Bool)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var runningListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var debounceTask: Task<Void, Never>?
    private var promptedThisSession = false
    private var isRunning = false

    /// Mic must stay active this long before we treat it as a real call (filters
    /// out Siri, dictation, voice-search, and brief permission blips).
    private let debounceSeconds: UInt64 = 10

    private static var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var runningSomewhereAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        addDefaultDeviceListener()
        bindToDefaultInput()
        Log.info("CallDetector started")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        debounceTask?.cancel(); debounceTask = nil
        removeRunningListener()
        removeDefaultDeviceListener()
        promptedThisSession = false
        Log.info("CallDetector stopped")
    }

    // MARK: - Default-input binding

    /// Attach (or re-attach) the running-somewhere listener to the current default
    /// input device. Called at start and whenever the default input changes (e.g.
    /// the user plugs in a headset mid-session).
    private func bindToDefaultInput() {
        removeRunningListener()
        deviceID = currentDefaultInputDevice()
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else {
            Log.warn("CallDetector: no default input device")
            return
        }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.handleRunningChange() }
        }
        runningListener = block
        let status = AudioObjectAddPropertyListenerBlock(
            deviceID, &Self.runningSomewhereAddress, DispatchQueue.main, block
        )
        if status != noErr {
            Log.error("CallDetector: add running listener failed (\(status))")
        }
        // A call may already be in progress when we bind — evaluate immediately.
        handleRunningChange()
    }

    private func addDefaultDeviceListener() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.bindToDefaultInput() }
        }
        defaultDeviceListener = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &Self.defaultInputAddress, DispatchQueue.main, block
        )
    }

    private func removeRunningListener() {
        if let block = runningListener, deviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioObjectRemovePropertyListenerBlock(
                deviceID, &Self.runningSomewhereAddress, DispatchQueue.main, block
            )
        }
        runningListener = nil
    }

    private func removeDefaultDeviceListener() {
        if let block = defaultDeviceListener {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &Self.defaultInputAddress, DispatchQueue.main, block
            )
        }
        defaultDeviceListener = nil
    }

    // MARK: - State changes

    private func handleRunningChange() {
        let active = readIsRunningSomewhere()
        if active {
            // Mic is (or just became) active. Start the debounce once; if it stays
            // active past the window and we're idle, we'll prompt exactly once.
            guard !promptedThisSession, debounceTask == nil else { return }
            debounceTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.debounceSeconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                self.debounceTask = nil
                // Re-check: still in use, and Glyph still idle?
                guard self.readIsRunningSomewhere() else { return }
                if self.isBusy?() == true { return }
                self.promptedThisSession = true
                Log.info("CallDetector: mic active past debounce — offering to record")
                self.onCallLikelyStarted?()
            }
        } else {
            // Mic released — the call ended. Reset so the next call can prompt again.
            debounceTask?.cancel(); debounceTask = nil
            promptedThisSession = false
        }
    }

    // MARK: - CoreAudio reads

    private func readIsRunningSomewhere() -> Bool {
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID, &Self.runningSomewhereAddress, 0, nil, &size, &value
        )
        return status == noErr && value != 0
    }

    private func currentDefaultInputDevice() -> AudioObjectID {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &Self.defaultInputAddress, 0, nil, &size, &id
        )
        return status == noErr ? id : AudioObjectID(kAudioObjectUnknown)
    }
}
