import Testing

@testable import MoviePilotCore

struct AdaptiveNavigationLayoutTests {
  @Test func compactPhonesAndFoldedWindowsKeepTabs() {
    for width in [320.0, 375, 390, 430, 560, 639] {
      #expect(
        !AdaptiveNavigationLayout(
          width: width, height: 850,
          regularWidth: true, regularHeight: true
        ).usesSidebar)
    }
    #expect(
      !AdaptiveNavigationLayout(
        width: 900, height: 430,
        regularWidth: true, regularHeight: false
      ).usesSidebar)
    #expect(
      !AdaptiveNavigationLayout(
        width: 900, height: 900,
        regularWidth: false, regularHeight: true
      ).usesSidebar)
  }

  @Test func expandedWindowsReserveReadableContent() {
    for width in [760.0, 840, 1024, 1366] {
      let layout = AdaptiveNavigationLayout(
        width: width, height: 800,
        regularWidth: true, regularHeight: true)
      #expect(layout.usesSidebar)
      #expect(width - layout.sidebarWidth >= 440)
      let largeText = AdaptiveNavigationLayout(
        width: width, height: 800,
        regularWidth: true, regularHeight: true, accessibilityText: true)
      #expect(largeText.sidebarWidth > layout.sidebarWidth)
      #expect(width - largeText.sidebarWidth >= 440)
    }
  }

  @Test func mediumExpandedWindowKeepsUsefulContentWidth() {
    let portrait = AdaptiveNavigationLayout(
      width: 669, height: 951,
      regularWidth: true, regularHeight: true)
    #expect(portrait.usesSidebar)
    #expect(portrait.sidebarWidth == 229)
    #expect(
      !AdaptiveNavigationLayout(
        width: 669, height: 951,
        regularWidth: true, regularHeight: true, accessibilityText: true
      ).usesSidebar)
  }

  @Test func fullscreenAndInvalidGeometryNeverReserveSidebarSpace() {
    #expect(
      !AdaptiveNavigationLayout(
        width: 900, height: 900, regularWidth: true,
        regularHeight: true, navigationVisible: false
      ).usesSidebar)
    for width in [Double.nan, .infinity, -1, 0] {
      #expect(
        !AdaptiveNavigationLayout(
          width: width, height: 900,
          regularWidth: true, regularHeight: true
        ).usesSidebar)
    }
  }
}
