import Foundation

/// Navigation follows the space available to this window, never a device model or hinge angle.
public struct AdaptiveNavigationLayout: Equatable, Sendable {
  public let sidebarWidth: Double
  public var usesSidebar: Bool { sidebarWidth > 0 }

  public init(
    width: Double, height: Double, regularWidth: Bool, regularHeight: Bool,
    accessibilityText: Bool = false, navigationVisible: Bool = true
  ) {
    // Leave a useful content column even at large text sizes. Short landscape phones keep tabs.
    let preferredSidebar: Double = accessibilityText ? 280 : 240
    let minimumContent: Double = 440
    let minimumSidebar: Double = accessibilityText ? 280 : 200
    let expanded =
      navigationVisible && regularWidth && regularHeight
      && width.isFinite && height.isFinite && height >= 500
      && width >= minimumSidebar + minimumContent
    sidebarWidth = expanded ? min(preferredSidebar, width - minimumContent) : 0
  }
}
