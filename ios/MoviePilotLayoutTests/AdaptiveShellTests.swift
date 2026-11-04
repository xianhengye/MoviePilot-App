import MoviePilotCore
import UIKit
import WebKit
import XCTest

@testable import MoviePilot

/// Exercises the production shell with synthetic snapshots and a local HTML document, without login.
@MainActor
final class AdaptiveShellTests: XCTestCase {
  private var window: UIWindow!
  private var shell: ShellController!
  private var coordinator: WebCoordinator!

  override func setUp() async throws {
    let instance = SavedInstance(id: UUID(), address: try ServerAddress("http://127.0.0.1:9"))
    let session = try AuthenticationSession(
      loginData: Data(
        #"{"access_token":"layout-fixture","super_user":true,"user_id":1,"user_name":"Fixture"}"#
          .utf8))
    coordinator = WebCoordinator(
      instance: instance,
      authentication: AuthenticationResult(session: session, cookies: []),
      onAuthenticationRequired: {})
    shell = ShellController(coordinator: coordinator, onConnection: {})
    coordinator.shell = shell
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
    window = UIWindow(windowScene: scene)
    let parent = UIViewController()
    window.rootViewController = parent
    window.makeKeyAndVisible()
    parent.addChild(shell)
    parent.view.addSubview(shell.view)
    shell.didMove(toParent: parent)
    shell.setLoading(false)
  }

  override func tearDown() async throws {
    coordinator.stop()
    window.isHidden = true
    window.rootViewController = nil
    shell = nil
    coordinator = nil
    window = nil
  }

  private func resize(width: CGFloat, height: CGFloat, regular: Bool, tall: Bool = true) {
    shell.traitOverrides.horizontalSizeClass = regular ? .regular : .compact
    shell.traitOverrides.verticalSizeClass = tall ? .regular : .compact
    shell.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
    shell.view.setNeedsLayout()
    shell.view.layoutIfNeeded()
    shell.view.layoutIfNeeded()
  }

  private func snapshot(overlay: Bool = false, fullscreen: Bool = false) throws
    -> NavigationSnapshot
  {
    let json = """
      {"route":{"fullPath":"/recommend","rootId":"recommend","title":"推荐","canGoBack":false},
       "roots":[{"id":"dashboard","path":"/dashboard","title":"仪表盘","icon":"mdi-view-dashboard"},
                {"id":"recommend","path":"/recommend","title":"推荐","icon":"mdi-star"},
                {"id":"discover","path":"/discover","title":"探索","icon":"mdi-compass"},
                {"id":"apps","path":"/apps","title":"更多","icon":"mdi-apps"}],
       "headerTabs":{"ownerId":"fixture-tabs","selectedId":"movie","items":[
          {"id":"movie","title":"电影"},{"id":"tv","title":"电视剧"}]},
       "actions":[],"chrome":{"topVisible":true,"bottomVisible":true,"theme":"system"},
       "moreMenu":[{"id":"library","title":"媒体库","items":[
          {"id":"downloads","path":"/downloads","title":"下载管理","icon":"mdi-download"}]}],
       "presentation":{"overlayOpen":\(overlay),"fullscreen":\(fullscreen)}}
      """
    return try JSONDecoder().decode(NavigationSnapshot.self, from: Data(json.utf8))
  }

  private func find(_ id: String) throws -> UIView {
    func search(_ view: UIView) -> UIView? {
      if view.accessibilityIdentifier == id { return view }
      return view.subviews.lazy.compactMap(search).first
    }
    return try XCTUnwrap(search(shell.view), id)
  }

  private func capture(_ name: String) {
    let renderer = UIGraphicsImageRenderer(bounds: shell.view.bounds)
    let image = renderer.image { _ in
      shell.view.drawHierarchy(in: shell.view.bounds, afterScreenUpdates: true)
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testFoldRoundTripPreservesDocumentAndNavigation() async throws {
    resize(width: 1100, height: 900, regular: true)
    shell.apply(try snapshot())
    shell.setLoading(false)
    shell.view.layoutIfNeeded()
    let webView = coordinator.webView
    // The production delegate intentionally rejects about:blank; this fixture has no server.
    webView.navigationDelegate = nil
    webView.loadHTMLString(
      "<meta name='viewport' content='width=device-width'><input id='query' value='保留搜索'><div style='height:3000px'>布局测试</div>",
      baseURL: nil)
    for _ in 0..<100 {
      if (try? await webView.evaluateJavaScript("document.getElementById('query') !== null"))
        as? Bool == true
      {
        break
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    _ = try await webView.evaluateJavaScript(
      "window.fixtureIdentity='same-document'; window.scrollTo(0,200)")
    let parent = coordinator.content.parent
    XCTAssertFalse(try find("native-sidebar-navigation").isHidden)
    XCTAssertTrue(try find("native-bottom-navigation").isHidden)
    XCTAssertNotNil(
      (parent as? ContentHostController)?.navigationItem.titleView as? UISegmentedControl)
    XCTAssertEqual(parent?.additionalSafeAreaInsets.bottom, 0)
    capture("expanded-navigation")

    for _ in 0..<3 {
      resize(width: 390, height: 844, regular: false)
      XCTAssertTrue(try find("native-sidebar-navigation").isHidden)
      XCTAssertFalse(try find("native-bottom-navigation").isHidden)
      XCTAssertGreaterThan(parent?.additionalSafeAreaInsets.bottom ?? 0, 0)
      XCTAssertTrue(coordinator.content.parent === parent)
      XCTAssertTrue(coordinator.webView === webView)
      let query =
        try await webView.evaluateJavaScript("document.getElementById('query').value") as? String
      XCTAssertEqual(query, "保留搜索")
      resize(width: 1100, height: 900, regular: true)
      XCTAssertFalse(try find("native-sidebar-navigation").isHidden)
      XCTAssertTrue(try find("native-bottom-navigation").isHidden)
      XCTAssertTrue(coordinator.content.parent === parent)
    }
    let identity = try await webView.evaluateJavaScript("window.fixtureIdentity") as? String
    XCTAssertEqual(identity, "same-document")
    resize(width: 390, height: 844, regular: false)
    capture("compact-navigation")
  }

  func testPhoneLandscapeAndFullscreenDoNotReserveSidebar() throws {
    resize(width: 852, height: 393, regular: true, tall: false)
    shell.apply(try snapshot())
    shell.view.layoutIfNeeded()
    XCTAssertTrue(try find("native-sidebar-navigation").isHidden)
    XCTAssertFalse(try find("native-bottom-navigation").isHidden)
    resize(width: 1100, height: 900, regular: true)
    shell.apply(try snapshot(overlay: true, fullscreen: true))
    shell.view.layoutIfNeeded()
    XCTAssertTrue(try find("native-sidebar-navigation").isHidden)
    XCTAssertTrue(try find("native-bottom-navigation").isHidden)
    XCTAssertEqual(coordinator.content.parent?.additionalSafeAreaInsets.bottom, 0)
  }

  func testSidebarOverlayAndLargeText() throws {
    resize(width: 1100, height: 900, regular: true)
    shell.apply(try snapshot(overlay: true))
    shell.view.layoutIfNeeded()
    let sidebar = try find("native-sidebar-navigation")
    XCTAssertTrue(sidebar.accessibilityElementsHidden)
    XCTAssertFalse(try find("native-sidebar-list").isUserInteractionEnabled)
    shell.apply(try snapshot())
    shell.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    shell.view.layoutIfNeeded()
    XCTAssertEqual(sidebar.bounds.width, 280, accuracy: 1)
    XCTAssertFalse(sidebar.accessibilityElementsHidden)
    XCTAssertNil(
      (coordinator.content.parent as? ContentHostController)?.navigationItem.titleView
        as? UISegmentedControl)
    capture("expanded-large-text")
  }

  func testSidebarKeepsConfirmedSelectionUntilRouteAcknowledgement() throws {
    resize(width: 1100, height: 900, regular: true)
    shell.apply(try snapshot())
    shell.view.layoutIfNeeded()
    let sidebar = try XCTUnwrap(
      shell.children.compactMap { $0 as? SidebarNavigationController }.first)
    let list = try XCTUnwrap(find("native-sidebar-list") as? UICollectionView)
    var requested: String?
    sidebar.onSelectRoot = { requested = $0 }
    sidebar.collectionView(list, didSelectItemAt: IndexPath(item: 0, section: 0))
    XCTAssertEqual(requested, "dashboard")
    XCTAssertEqual(list.indexPathsForSelectedItems, [IndexPath(item: 1, section: 0)])
    shell.apply(try snapshot(overlay: true))
    requested = nil
    sidebar.collectionView(list, didSelectItemAt: IndexPath(item: 0, section: 0))
    XCTAssertNil(requested)
    shell.apply(try snapshot())
    sidebar.collectionView(list, didSelectItemAt: IndexPath(item: 0, section: 0))
    XCTAssertEqual(requested, "dashboard")
  }

  func testMediumExpandedPortraitUsesNarrowerSidebar() throws {
    resize(width: 669, height: 951, regular: true)
    shell.apply(try snapshot())
    shell.view.layoutIfNeeded()
    let sidebar = try find("native-sidebar-navigation")
    XCTAssertFalse(sidebar.isHidden)
    XCTAssertLessThanOrEqual(sidebar.bounds.width, 240)
    XCTAssertGreaterThanOrEqual(coordinator.content.view.bounds.width, 440)
    capture("expanded-portrait")
  }

  func testRightToLeftSidebarReservesTrailingSpace() throws {
    resize(width: 1100, height: 900, regular: true)
    shell.view.semanticContentAttribute = .forceRightToLeft
    shell.traitOverrides.layoutDirection = .rightToLeft
    shell.apply(try snapshot())
    shell.view.layoutIfNeeded()
    let sidebar = try find("native-sidebar-navigation")
    let content = coordinator.content.view.convert(coordinator.content.view.bounds, to: shell.view)
    XCTAssertGreaterThanOrEqual(sidebar.frame.minX, content.maxX - 1)
  }
}
