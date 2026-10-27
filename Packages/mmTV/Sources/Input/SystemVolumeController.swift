import CoreAudio
import AudioToolbox

public enum SystemVolumeController {
    public static let step: Float32 = 0.0625

    public static func currentVolume() -> Float32? {
        guard let device = defaultOutputDevice(),
              var address = volumeAddress(for: device) else { return nil }
        var value = Float32.zero
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return min(max(value, 0), 1)
    }

    @discardableResult public static func adjust(by delta: Float32) -> Float32? {
        guard let device = defaultOutputDevice(),
              var address = volumeAddress(for: device),
              var value = currentVolume() else { return nil }
        value = min(max(value + delta, 0), 1)
        let size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr else { return nil }
        return value
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        ) == noErr, device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static func volumeAddress(for device: AudioObjectID) -> AudioObjectPropertyAddress? {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            kAudioDevicePropertyVolumeScalar,
        ]
        for selector in selectors {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var settable = DarwinBoolean(false)
            if AudioObjectHasProperty(device, &address),
               AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
               settable.boolValue {
                return address
            }
        }
        return nil
    }
}
