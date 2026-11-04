import MoviePilotCore
import UIKit
import WebKit
import XCTest

@testable import MoviePilot

/// Exercises the production shell with synthetic snapshots and a local HTML document, without login.
@available(iOS 18.4, *)
@MainActor
final class AdaptiveShellTests: XCTestCase {
  private var window: UIWindow!
  private var shell: DuoShellController!
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
    shell = DuoShellController(coordinator: coordinator, onConnection: {})
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

  private func tabs() throws -> UITabBarController {
    try XCTUnwrap(shell.children.compactMap { $0 as? UITabBarController }.first)
  }

  func testSystemTabsOwnNavigationWithoutCustomRails() throws {
    resize(width: 466, height: 678, regular: false)
    shell.apply(try snapshot())
    shell.view.layoutIfNeeded()
    let tabs = try tabs()
    XCTAssertEqual(tabs.tabs.map(\.title).prefix(4), ["仪表盘", "推荐", "探索", "更多"])
    XCTAssertTrue(tabs.tabs.last is UISearchTab)
    XCTAssertEqual(tabs.selectedTab?.identifier, "recommend")
    XCTAssertFalse(tabs.isTabBarHidden)
    XCTAssertTrue(coordinator.content.parent?.navigationController?.parent === tabs)
    XCTAssertEqual(coordinator.content.parent?.additionalSafeAreaInsets, .zero)
    XCTAssertTrue(
      shell.children.allSatisfy { $0 is UITabBarController || $0 is UINavigationController })
    capture("system-tabs-compact")
  }

  func testFoldAndSplitResizePreserveDocument() async throws {
    resize(width: 1100, height: 900, regular: true)
    shell.apply(try snapshot())
    shell.setLoading(false)
    shell.view.layoutIfNeeded()
    let web = coordinator.webView
    web.navigationDelegate = nil
    web.loadHTMLString("<input id='query' value='保留搜索'>", baseURL: nil)
    for _ in 0..<100 {
      if (try? await web.evaluateJavaScript("document.getElementById('query') !== null")) as? Bool
        == true
      {
        break
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    let parent = coordinator.content.parent
    let tabs = try tabs()
    for width in [466.0, 430, 1100, 500, 390, 1100] {
      resize(width: width, height: 678, regular: width > 600)
      XCTAssertTrue(coordinator.webView === web)
      XCTAssertTrue(coordinator.content.parent === parent)
      XCTAssertEqual(tabs.selectedTab?.identifier, "recommend")
      XCTAssertEqual(parent?.additionalSafeAreaInsets, .zero)
      let value =
        try await web.evaluateJavaScript("document.getElementById('query').value") as? String
      XCTAssertEqual(value, "保留搜索")
    }
    capture("system-tabs-expanded")
  }

  func testUnconfirmedSelectionAndOverlayRemainGuarded() throws {
    resize(width: 466, height: 678, regular: false)
    shell.apply(try snapshot())
    let tabs = try tabs()
    XCTAssertFalse(shell.tabBarController(tabs, shouldSelectTab: tabs.tabs[0]))
    XCTAssertEqual(tabs.selectedTab?.identifier, "recommend")
    shell.apply(try snapshot(overlay: true))
    XCTAssertTrue(tabs.tabs.allSatisfy { !$0.isEnabled })
    XCTAssertFalse(shell.tabBarController(tabs, shouldSelectTab: tabs.tabs[0]))
    shell.apply(try snapshot())
    XCTAssertTrue(tabs.tabs[0].isEnabled)
    shell.apply(try snapshot(overlay: true, fullscreen: true))
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertEqual(coordinator.content.parent?.additionalSafeAreaInsets, .zero)
  }

  func testConfirmedRootSwitchKeepsSingleWebViewAndSystemHierarchy() throws {
    resize(width: 466, height: 678, regular: false)
    let original = try snapshot()
    shell.apply(original)
    let web = coordinator.webView
    var json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    json["route"] = [
      "fullPath": "/dashboard", "rootId": "dashboard", "title": "仪表盘", "canGoBack": false,
    ]
    let next = try JSONDecoder().decode(
      NavigationSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    shell.apply(next)
    shell.view.layoutIfNeeded()
    XCTAssertEqual(try tabs().selectedTab?.identifier, "dashboard")
    XCTAssertTrue(coordinator.webView === web)
    XCTAssertTrue(coordinator.content.parent?.navigationController?.parent === (try tabs()))
  }

  func testDeviceFactorySelectsIsolatedImplementations() throws {
    let duo = DeviceShellFactory.make(
      coordinator: coordinator, onConnection: {}, modelIdentifier: "iPhone19,4")
    XCTAssertTrue(duo is DuoShellController)
    for model in ["iPhone19,1", "iPhone19,2", "iPhone19,3", "iPad17,2", "unknown"] {
      let original = DeviceShellFactory.make(
        coordinator: coordinator, onConnection: {}, modelIdentifier: model)
      XCTAssertTrue(original is ShellController, model)
      XCTAssertFalse(original is DuoShellController, model)
      original.loadViewIfNeeded()
      original.traitOverrides.horizontalSizeClass = .regular
      original.traitOverrides.verticalSizeClass = .regular
      original.view.frame = CGRect(x: 0, y: 0, width: 1100, height: 900)
      original.apply(try snapshot())
      original.setLoading(false)
      original.view.layoutIfNeeded()
      func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
      let views = descendants(original.view)
      XCTAssertFalse(views.contains { $0.accessibilityIdentifier == "duo-system-tabs" }, model)
      let bottom = try XCTUnwrap(
        views.first { $0.accessibilityIdentifier == "native-bottom-navigation" })
      XCTAssertFalse(bottom.isHidden, model)
    }
  }
}
