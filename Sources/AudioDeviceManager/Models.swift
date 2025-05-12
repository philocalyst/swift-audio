import CoreAudio
import Foundation

/// Represents types of audio devices
public enum AudioDeviceType: String, CaseIterable, Codable {
  case input
  case output
  case systemOutput
  case all

  internal var selector: AudioObjectPropertySelector {
    switch self {
    case .input:
      return kAudioHardwarePropertyDefaultInputDevice
    case .output, .all:
      return kAudioHardwarePropertyDefaultOutputDevice
    case .systemOutput:
      return kAudioHardwarePropertyDefaultSystemOutputDevice
    }
  }

  internal var scope: AudioObjectPropertyScope {
    switch self {
    case .input:
      return kAudioDevicePropertyScopeInput
    case .output, .systemOutput, .all:
      return kAudioDevicePropertyScopeOutput
    }
  }
}

/// Represents the mute status for an audio device
public enum MuteAction: String, Codable {
  case mute
  case unmute
  case toggle
}

/// Represents the output format for device information
public enum OutputFormat: String, Codable {
  case human
  case cli
  case json
}

/// Represents an audio device in the system
public struct AudioDevice: Identifiable, Codable, Equatable, Hashable {
  public let id: AudioDeviceID
  public let name: String
  public let uid: String
  public let type: AudioDeviceType
  public var isDefault: Bool

  public static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension AudioDevice {
  /// Creates a formatted string representation based on the specified format
  /// - Parameter format: The desired output format
  /// - Returns: A formatted string representation of the device
  public func formatted(as format: OutputFormat) -> String {
    switch format {
    case .human:
      return name
    case .cli:
      return "\(name),\(type.rawValue),\(id),\(uid)"
    case .json:
      let jsonObj: [String: Any] = [
        "name": name,
        "type": type.rawValue,
        "id": id,
        "uid": uid,
        "isDefault": isDefault,
      ]

      do {
        let jsonData = try JSONSerialization.data(
          withJSONObject: jsonObj, options: [.prettyPrinted])
        if let jsonString = String(data: jsonData, encoding: .utf8) {
          return jsonString
        }
      } catch {
        // Fallback to a basic format if JSON serialization fails
        return
          "{\"name\": \"\(name)\", \"type\": \"\(type.rawValue)\", \"id\": \"\(id)\", \"uid\": \"\(uid)\"}"
      }

      // Fallback to a basic format if JSON serialization fails
      return
        "{\"name\": \"\(name)\", \"type\": \"\(type.rawValue)\", \"id\": \"\(id)\", \"uid\": \"\(uid)\"}"
    }
  }
}
