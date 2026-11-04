import MoviePilotCore
import UIKit

/// Shared bridge contract; device-specific shells own their UI without changing business routing.
@MainActor
protocol NativeShell: AnyObject where Self: UIViewController {
  func setLoading(_ loading: Bool)
  func prepareDocumentHost()
  func prepare(_ snapshot: NavigationSnapshot)
  func apply(_ snapshot: NavigationSnapshot)
  func layoutPayload(revision: Int, keyboard: CGRect?) -> JSONValue
  func captureNavigationPreview()
  func clearNavigationPreviews()
  func showStartupWait()
  func showRecovery(message: String)
  func showNotificationMessage(_ message: String)
  func openHomeShortcut(_ action: ActionSnapshot) -> Bool
}

// Conformance lives outside the original file to keep the upstream implementation byte-for-byte intact.
extension ShellController: NativeShell {}
extension DuoShellController: NativeShell {}
