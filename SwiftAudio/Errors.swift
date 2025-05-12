import CoreAudio
import Foundation

/// Errors that may occur during audio device operations
public enum AudioDeviceError: Error, LocalizedError {
  case deviceNotFound(String)
  case failedToGetDeviceList
  case failedToGetCurrentDevice(AudioDeviceType)
  case failedToSetDevice(AudioDeviceID, AudioDeviceType, OSStatus)
  case failedToGetDeviceName(AudioDeviceID)
  case failedToGetDeviceUID(AudioDeviceID)
  case failedToGetMuteStatus(AudioDeviceID)
  case failedToSetMuteStatus(AudioDeviceID, MuteAction, OSStatus)
  case failedToSetVolume(AudioDeviceID, OSStatus)
  case invalidDeviceType
  case invalidDeviceID(String)
  case operationNotSupported(String)

  public var errorDescription: String? {
    switch self {
    case .failedToSetVolume(let deviceID, let status):
      return "Failed to set device \(deviceID) volume. Error: \(status)"
    case .deviceNotFound(let name):
      return "Could not find audio device: \(name)"
    case .failedToGetDeviceList:
      return "Failed to retrieve the list of audio devices"
    case .failedToGetCurrentDevice(let type):
      return "Failed to get current \(type.rawValue) device"
    case .failedToSetDevice(let deviceID, let type, let status):
      return "Failed to set \(type.rawValue) device \(deviceID). Error: \(status)"
    case .failedToGetDeviceName(let deviceID):
      return "Failed to retrieve name for device ID \(deviceID)"
    case .failedToGetDeviceUID(let deviceID):
      return "Failed to retrieve UID for device ID \(deviceID)"
    case .failedToGetMuteStatus(let deviceID):
      return "Failed to get mute status for device ID \(deviceID)"
    case .failedToSetMuteStatus(let deviceID, let action, let status):
      return "Failed to \(action.rawValue) device \(deviceID). Error: \(status)"
    case .invalidDeviceType:
      return "Invalid device type"
    case .invalidDeviceID(let id):
      return "Invalid device ID: \(id)"
    case .operationNotSupported(let operation):
      return "Operation not supported: \(operation)"
    }
  }
}
