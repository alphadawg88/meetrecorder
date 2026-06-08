import Foundation
import CoreAudio

func findDeviceID(name: String, isInput: Bool) -> AudioDeviceID? {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
    guard status == noErr else { return nil }
    
    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
    guard status == noErr else { return nil }
    
    for deviceID in deviceIDs {
        var nameProperty = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameData: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        let nameStatus = AudioObjectGetPropertyData(deviceID, &nameProperty, 0, nil, &nameSize, &nameData)
        guard nameStatus == noErr else { continue }
        let deviceName = nameData as String
        
        // Check if device has the right direction
        var streamProperty = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamSize: UInt32 = 0
        let streamStatus = AudioObjectGetPropertyDataSize(deviceID, &streamProperty, 0, nil, &streamSize)
        guard streamStatus == noErr, streamSize > 0 else { continue }
        
        if deviceName.localizedCaseInsensitiveContains(name) {
            return deviceID
        }
    }
    return nil
}

func setDefaultDevice(deviceID: AudioDeviceID, isInput: Bool) -> Bool {
    let selector = isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var id = deviceID
    let status = AudioObjectSetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        UInt32(MemoryLayout<AudioDeviceID>.size),
        &id
    )
    return status == noErr
}

@main
struct SetDefaultOutput {
    static func main() {
        let args = CommandLine.arguments
        if args.count < 2 {
            print("Usage: set-default-output <device-name-substring>")
            exit(1)
        }
        
        let name = args[1]
        if let deviceID = findDeviceID(name: name, isInput: false) {
            if setDefaultDevice(deviceID: deviceID, isInput: false) {
                print("Set default output to device containing '\(name)'")
            } else {
                print("Failed to set default output")
                exit(1)
            }
        } else {
            print("Output device containing '\(name)' not found")
            exit(1)
        }
    }
}
