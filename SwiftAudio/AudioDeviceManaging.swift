import CoreAudio
import Foundation

/// Protocol defining the core functionality for audio device management
public protocol AudioDeviceManaging {
  /// Gets the list of all audio devices of a specific type
  /// - Parameter type: The type of audio devices to retrieve
  /// - Returns: An array of audio devices
  func getDevices(ofType type: AudioDeviceType) async throws -> [AudioDevice]

  /// Gets the currently selected audio device for a specific type
  /// - Parameter type: The type of audio device to get
  /// - Returns: The currently selected audio device
  func getCurrentDevice(type: AudioDeviceType) async throws -> AudioDevice

  /// Sets the default audio device by its ID
  /// - Parameters:
  ///   - deviceID: The ID of the device to set as default
  ///   - type: The type of device to set
  /// - Returns: The newly set device
  func setDefaultDevice(for deviceID: AudioDeviceID, type: AudioDeviceType) async throws
    -> AudioDevice

  /// Sets the default audio device by its name
  /// - Parameters:
  ///   - name: The name of the device to set as default
  ///   - type: The type of device to set
  /// - Returns: The newly set device
  func setDefaultDevice(byName name: String, type: AudioDeviceType) async throws -> AudioDevice

  /// Sets the default audio device by a substring of its UID
  /// - Parameters:
  ///   - uidSubstring: A substring of the device UID
  ///   - type: The type of device to set
  /// - Returns: The newly set device
  func setDefaultDevice(byUIDSubstring uidSubstring: String, type: AudioDeviceType) async throws
    -> AudioDevice

  /// Cycles to the next available audio device of the specified type
  /// - Parameter type: The type of device to cycle
  /// - Returns: The new current device after cycling
  func cycleToNextDevice(type: AudioDeviceType) async throws -> AudioDevice

  /// Sets the mute status for the current audio device of the specified type
  /// - Parameters:
  ///   - action: The mute action to perform
  ///   - type: The type of device to modify
  /// - Returns: A boolean indicating if the device is now muted
  func setMuteStatus(_ action: MuteAction, forType type: AudioDeviceType) async throws -> Bool
}

/// Helper functions for working with Core Audio properties
internal func createPropertyAddress(
  selector: AudioObjectPropertySelector,
  scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
  element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) -> AudioObjectPropertyAddress {
  return AudioObjectPropertyAddress(
    mSelector: selector,
    mScope: scope,
    mElement: element
  )
}

/// Extension to get formatted OSStatus error descriptions
extension OSStatus {
  var errorDescription: String {
    if let errorString = (self as OSStatus).errorMessage {
      return errorString
    } else {
      return String(self)
    }
  }

  var errorMessage: String? {
    let errorLen = 4
    let status = Int32(self)

    guard status != 0 else { return nil }

    // Convert the OSStatus to a 4-char code
    var result: String = ""
    for i in 0..<4 {
      let unichar = UnicodeScalar((Int(status) >> (errorLen - 1 - i) * 8) & 0xff)
      if let scalar = unichar {
        if scalar.isASCII && !scalar.properties.isBidiControl {
          result.unicodeScalars.append(scalar)
        } else {
          return "Error code: \(status)"
        }
      }
    }

    return result.isEmpty ? "Error code: \(status)" : result
  }
}
