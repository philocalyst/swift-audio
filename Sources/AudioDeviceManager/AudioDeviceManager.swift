import CoreAudio
import Foundation

/// Main implementation of the AudioDeviceManaging protocol
public class AudioDeviceManager: AudioDeviceManaging {
  /// Shared singleton instance
  public static let shared = AudioDeviceManager()

  /// A Boolean value indicating whether to sync the system sound effects output with the main output
  public var syncSoundEffectsOutput: Bool = false

  /// Initialize a new AudioDeviceManager
  public init() {}

  /// Gets the list of all audio devices of a specific type
  /// - Parameter type: The type of audio devices to retrieve
  /// - Returns: An array of audio devices
  public func getDevices(ofType type: AudioDeviceType) async throws -> [AudioDevice] {
    let currentDevice = try await getCurrentDevice(type: type)
    let allDevices = try await getAllDevices(ofType: type)

    return allDevices.map { device in
      var deviceCopy = device
      deviceCopy.isDefault = device.id == currentDevice.id
      return deviceCopy
    }
  }

  /// Gets the currently selected audio device for a specific type
  /// - Parameter type: The type of audio device to get
  /// - Returns: The currently selected audio device
  public func getCurrentDevice(type: AudioDeviceType) async throws -> AudioDevice {
    var propertyAddress = createPropertyAddress(selector: type.selector)
    var deviceID = AudioDeviceID()
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &deviceID
    )

    guard status == noErr else {
      throw AudioDeviceError.failedToGetCurrentDevice(type)
    }

    let name = try getDeviceName(deviceID: deviceID)
    let uid = try getDeviceUID(deviceID: deviceID)

    return AudioDevice(
      id: deviceID,
      name: name,
      uid: uid,
      type: type,
      isDefault: true
    )
  }

  /// Sets the default audio device
  /// - Parameters:
  ///   - device: The device to set as default
  ///   - type: The type of device to set
  /// - Returns: The newly set device
  public func setDefaultDevice(_ device: AudioDevice, type: AudioDeviceType) async throws
    -> AudioDevice
  {
    return try await setDefaultDevice(byID: device.id, type: type)
  }

  /// Sets the default audio device by its ID
  /// - Parameters:
  ///   - deviceID: The ID of the device to set as default
  ///   - type: The type of device to set
  /// - Returns: The newly set device
  public func setDefaultDevice(byID deviceID: AudioDeviceID, type: AudioDeviceType) async throws
    -> AudioDevice
  {
    var propertyAddress = createPropertyAddress(selector: type.selector)
    var newDeviceID = deviceID
    let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectSetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      propertySize,
      &newDeviceID
    )

    guard status == noErr else {
      throw AudioDeviceError.failedToSetDevice(deviceID, type, status)
    }

    // Handle syncing system sound effects if needed
    if type == .output && syncSoundEffectsOutput {
      try await setSoundEffectsOutput(to: deviceID)
    }

    // Get the updated device information
    let name = try getDeviceName(deviceID: deviceID)
    let uid = try getDeviceUID(deviceID: deviceID)

    return AudioDevice(
      id: deviceID,
      name: name,
      uid: uid,
      type: type,
      isDefault: true
    )
  }

  /// Sets the default audio device by its name
  /// - Parameters:
  ///   - name: The name of the device to set as default
  ///   - type: The type of device to set
  /// - Returns: The newly set device
  public func setDefaultDevice(byName name: String, type: AudioDeviceType) async throws
    -> AudioDevice
  {
    let devices = try await getAllDevices(ofType: type)

    guard let device = devices.first(where: { $0.name == name }) else {
      throw AudioDeviceError.deviceNotFound(name)
    }

    return try await setDefaultDevice(byID: device.id, type: type)
  }

  public func jackConnected() throws -> Bool {
    return kAudioDevicePropertyJackIsConnected != 0
  }

  /// Sets the default audio device by a substring of its UID
  /// - Parameters:
  ///   - uidSubstring: A substring of the device UID
  ///   - type: The type of device to set
  /// - Returns: The newly set device
  public func setDefaultDevice(byUIDSubstring uidSubstring: String, type: AudioDeviceType)
    async throws -> AudioDevice
  {
    let devices = try await getAllDevices(ofType: type)

    guard let device = devices.first(where: { $0.uid.contains(uidSubstring) }) else {
      throw AudioDeviceError.deviceNotFound("with UID containing \(uidSubstring)")
    }

    return try await setDefaultDevice(byID: device.id, type: type)
  }

  /// Cycles to the next available audio device of the specified type
  /// - Parameter type: The type of device to cycle
  /// - Returns: The new current device after cycling
  public func cycleToNextDevice(type: AudioDeviceType) async throws -> AudioDevice {
    if type == .all {
      // Handle cycling all device types
      var anyError: Error? = nil

      do {
        _ = try await cycleToNextDevice(type: .input)
      } catch {
        anyError = error
      }

      do {
        _ = try await cycleToNextDevice(type: .output)
      } catch {
        anyError = error
      }

      if let error = anyError {
        throw error
      }

      return try await getCurrentDevice(type: .output)
    } else {
      // Get current device
      let currentDevice = try await getCurrentDevice(type: type)

      // Get all devices of the requested type
      let devices = try await getAllDevices(ofType: type)
      guard !devices.isEmpty else {
        throw AudioDeviceError.deviceNotFound("No devices of type \(type.rawValue) found")
      }

      // Find the index of the current device
      let currentIndex = devices.firstIndex(where: { $0.id == currentDevice.id }) ?? -1

      // Get the next device (wrapping around if needed)
      let nextIndex = (currentIndex + 1) % devices.count
      let nextDevice = devices[nextIndex]

      // Set the next device as default
      return try await setDefaultDevice(byID: nextDevice.id, type: type)
    }
  }

  /// Sets the mute status for the current audio device of the specified type
  /// - Parameters:
  ///   - action: The mute action to perform
  ///   - type: The type of device to modify
  /// - Returns: A boolean indicating if the device is now muted
  public func setMuteStatus(_ action: MuteAction, forType type: AudioDeviceType) async throws
    -> Bool
  {
    if type == .all {
      // Handle setting mute for all device types
      var anyError: Error? = nil
      var resultInput = false
      var resultOutput = false

      do {
        resultInput = try await setMuteStatus(action, forType: .input)
      } catch {
        anyError = error
      }

      do {
        resultOutput = try await setMuteStatus(action, forType: .output)
      } catch {
        anyError = error
      }

      if let error = anyError {
        throw error
      }

      // Return the output device mute status as the overall result
      return resultOutput
    } else if type == .systemOutput {
      throw AudioDeviceError.operationNotSupported("Cannot mute system output device")
    } else {
      let currentDevice = try await getCurrentDevice(type: type)

      var propertyAddress = createPropertyAddress(
        selector: kAudioDevicePropertyMute,
        scope: type.scope
      )

      var muted: UInt32 = 0
      var propertySize = UInt32(MemoryLayout<UInt32>.size)

      // If the action is toggle, we need to get the current mute status first
      if action == .toggle {
        let status = AudioObjectGetPropertyData(
          currentDevice.id,
          &propertyAddress,
          0,
          nil,
          &propertySize,
          &muted
        )

        guard status == noErr else {
          throw AudioDeviceError.failedToGetMuteStatus(currentDevice.id)
        }

        // Toggle the mute status
        muted = muted == 0 ? 1 : 0
      } else {
        // Set mute based on the action
        muted = action == .mute ? 1 : 0
      }

      // Apply the mute setting
      let status = AudioObjectSetPropertyData(
        currentDevice.id,
        &propertyAddress,
        0,
        nil,
        propertySize,
        &muted
      )

      guard status == noErr else {
        throw AudioDeviceError.failedToSetMuteStatus(currentDevice.id, action, status)
      }

      return muted != 0
    }
  }

  // MARK: - Private Helper Methods

  /// Sets the system sound effects output to the specified device
  /// - Parameter deviceID: The device ID to set
  /// - Throws: An error if the operation fails
  private func setSoundEffectsOutput(to deviceID: AudioDeviceID) async throws {
    var propertyAddress = createPropertyAddress(
      selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
    var newDeviceID = deviceID
    let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectSetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      propertySize,
      &newDeviceID
    )

    guard status == noErr else {
      throw AudioDeviceError.failedToSetDevice(deviceID, .systemOutput, status)
    }
  }

  /// Gets the name of a device by its ID
  /// - Parameter deviceID: The device ID
  /// - Returns: The device name
  /// - Throws: An error if retrieving the name fails
  private func getDeviceName(deviceID: AudioDeviceID) throws -> String {
    var propertyAddress = createPropertyAddress(selector: kAudioDevicePropertyDeviceNameCFString)
    var deviceName: CFString = "" as CFString  // Not important to us
    var propertySize = UInt32(MemoryLayout<CFString>.size)

    let status = AudioObjectGetPropertyData(
      deviceID,
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &deviceName
    )

    guard status == noErr, let name = deviceName as String? else {
      throw AudioDeviceError.failedToGetDeviceName(deviceID)
    }

    return name
  }

  /// Gets the UID of a device by its ID
  /// - Parameter deviceID: The device ID
  /// - Returns: The device UID
  /// - Throws: An error if retrieving the UID fails
  private func getDeviceUID(deviceID: AudioDeviceID) throws -> String {
    var propertyAddress = createPropertyAddress(selector: kAudioDevicePropertyDeviceUID)
    var deviceUID: CFString = "" as CFString  // Not important to us
    var propertySize = UInt32(MemoryLayout<CFString>.size)

    let status = AudioObjectGetPropertyData(
      deviceID,
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &deviceUID
    )

    guard status == noErr, let uid = deviceUID as String? else {
      throw AudioDeviceError.failedToGetDeviceUID(deviceID)
    }

    return uid
  }

  /// Determines if a device is an input device
  /// - Parameter deviceID: The device ID to check
  /// - Returns: True if the device is an input device, false otherwise
  private func isInputDevice(deviceID: AudioDeviceID) -> Bool {
    var propertyAddress = createPropertyAddress(
      selector: kAudioDevicePropertyStreams,
      scope: kAudioDevicePropertyScopeInput
    )

    var propertySize: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(
      deviceID,
      &propertyAddress,
      0,
      nil,
      &propertySize
    )

    return status == noErr && propertySize > 0
  }

  /// Determines if a device is an output device
  /// - Parameter deviceID: The device ID to check
  /// - Returns: True if the device is an output device, false otherwise
  private func isOutputDevice(deviceID: AudioDeviceID) -> Bool {
    var propertyAddress = createPropertyAddress(
      selector: kAudioDevicePropertyStreams,
      scope: kAudioDevicePropertyScopeOutput
    )

    var propertySize: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(
      deviceID,
      &propertyAddress,
      0,
      nil,
      &propertySize
    )

    return status == noErr && propertySize > 0
  }

  /// Gets all available audio devices of a specific type
  /// - Parameter type: The type of devices to retrieve
  /// - Returns: An array of audio devices
  private func getAllDevices(ofType type: AudioDeviceType) async throws -> [AudioDevice] {
    var propertyAddress = createPropertyAddress(selector: kAudioHardwarePropertyDevices)
    var propertySize: UInt32 = 0

    var status = AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize
    )

    guard status == noErr else {
      throw AudioDeviceError.failedToGetDeviceList
    }

    let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress,
      0,
      nil,
      &propertySize,
      &deviceIDs
    )

    guard status == noErr else {
      throw AudioDeviceError.failedToGetDeviceList
    }

    var devices: [AudioDevice] = []

    for id in deviceIDs {
      // Filter by device type
      switch type {
      case .input:
        if !isInputDevice(deviceID: id) { continue }
      case .output, .systemOutput:
        if !isOutputDevice(deviceID: id) { continue }
      case .all:
        // Include all devices
        break
      }

      do {
        let name = try getDeviceName(deviceID: id)
        let uid = try getDeviceUID(deviceID: id)

        devices.append(
          AudioDevice(
            id: id,
            name: name,
            uid: uid,
            type: type,
            isDefault: false
          ))
      } catch {
        // Skip devices that fail to retrieve name or UID
        continue
      }
    }

    return devices
  }
}
