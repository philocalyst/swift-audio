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

/// Represents an audio level 1–100
public struct Level {
  private let level: Int8

  /// The audio level value (1–100).
  public var value: Int8 {
    level
  }

  /// Creates a `Level` if `level` is between 1 and 100 inclusive.
  /// Returns `nil` if the provided value is out of range.
  public init?(level: Int8) {
    guard (1...100).contains(level) else {
      return nil
    }
    self.level = level
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

  /// Makes the device the default audio device
  /// - Parameters:
  ///   - type: The type of device to set
  public func makeDefault(for type: AudioDeviceType) async throws -> AudioDevice {
    let audioManger = AudioDeviceManager.init()
    return try await audioManger.setDefaultDevice(for: self.id, type: type)
  }

  public func setVolume(level: Level) async throws -> Int8 {
    var propertyAddress = createPropertyAddress(
      selector: kAudioDevicePropertyVolumeScalar, scope: self.type.scope)

    let propertySize = UInt32(MemoryLayout<UInt32>.size)

    var volume = UInt32(level.value)

    // Apply the volume
    let status = AudioObjectSetPropertyData(
      self.id,
      &propertyAddress,
      0,
      nil,
      propertySize,
      &volume
    )

    guard status == noErr else {
      throw AudioDeviceError.failedToSetVolume(self.id, status)
    }

    return level.value
  }
}
