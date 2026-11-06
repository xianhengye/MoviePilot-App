import Darwin
import MoviePilotCore
import UIKit

/// Choose once per authenticated session. Folding never replaces the active shell or its WebView.
@MainActor
enum DeviceShellFactory {
  static var currentModelIdentifier: String {
    #if targetEnvironment(simulator)
      return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
    #else
      var system = utsname()
      guard uname(&system) == 0 else { return "unknown" }
      return withUnsafeBytes(of: &system.machine) { bytes in
        String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
      }
    #endif
  }

  static func make(
    coordinator: WebCoordinator, onConnection: @escaping () -> Void,
    modelIdentifier: String = currentModelIdentifier
  ) -> any NativeShell {
    if ShellDevicePolicy.usesDuoInterface(modelIdentifier: modelIdentifier) {
      return DuoShellController(coordinator: coordinator, onConnection: onConnection)
    }
    return ShellController(coordinator: coordinator, onConnection: onConnection)
  }
}
