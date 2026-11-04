import MoviePilotCore
import UIKit

/// Expanded-window navigation uses system sidebar cells and the same confirmed web routes as tabs.
@MainActor
final class SidebarNavigationController: UIViewController, UICollectionViewDelegate {
  private struct Entry: Hashable {
    let id: String
    let title: String
    let icon: String
    let rootID: String?
    let menuID: String?
  }

  private var collectionView: UICollectionView!
  private var dataSource: UICollectionViewDiffableDataSource<Int, Entry>!
  private let actionHost = UIView()
  private var action: UIButton?
  private var lastRoots: [RootSnapshot] = []
  private var lastSections: [MoreMenuSection] = []
  private var selectedPath = ""
  private var selectedRoot: String?
  private var enabled = true
  var onSelectRoot: ((String) -> Void)?
  var onSelectMenu: ((MoreMenuItem) -> Void)?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.accessibilityIdentifier = "native-sidebar-navigation"
    view.backgroundColor = .clear
    let material: UIVisualEffect
    if #available(iOS 26.0, *) {
      material = UIGlassEffect(style: .regular)
    } else {
      material = UIBlurEffect(style: .systemMaterial)
    }
    let background = UIVisualEffectView(effect: material)
    background.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(background)
    NSLayoutConstraint.activate([
      background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      background.topAnchor.constraint(equalTo: view.topAnchor),
      background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    let title = UILabel()
    title.text = "MoviePilot"
    title.font = .preferredFont(forTextStyle: .title2)
    title.adjustsFontForContentSizeCategory = true
    title.accessibilityTraits = .header
    title.numberOfLines = 1
    title.adjustsFontSizeToFitWidth = true
    title.minimumScaleFactor = 0.5
    var configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
    configuration.backgroundColor = .clear
    configuration.headerMode = .supplementary
    collectionView = UICollectionView(
      frame: .zero,
      collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
    collectionView.backgroundColor = .clear
    collectionView.delegate = self
    collectionView.accessibilityIdentifier = "native-sidebar-list"
    actionHost.setContentHuggingPriority(.required, for: .vertical)
    for child in [title, collectionView!, actionHost] {
      child.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(child)
    }
    NSLayoutConstraint.activate([
      title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      title.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      collectionView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: actionHost.topAnchor, constant: -8),
      actionHost.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      actionHost.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      actionHost.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
      actionHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
    ])
    let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Entry> {
      cell, _, item in
      var content = UIListContentConfiguration.sidebarCell()
      content.text = item.title
      content.textProperties.numberOfLines = 0
      content.image = NavigationSymbols.image(
        item.icon, configuration: NavigationSymbols.bottomConfiguration)
      cell.contentConfiguration = content
      cell.accessibilityIdentifier = "native-sidebar-\(item.id)"
    }
    dataSource = UICollectionViewDiffableDataSource<Int, Entry>(collectionView: collectionView) {
      collectionView, indexPath, entry in
      collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: entry)
    }
    let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionHeader
    ) { [weak self] cell, _, indexPath in
      var content = UIListContentConfiguration.sidebarHeader()
      content.text = indexPath.section == 0 ? "导航" : self?.lastSections[indexPath.section - 1].title
      cell.contentConfiguration = content
    }
    dataSource.supplementaryViewProvider = { collection, _, indexPath in
      collection.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
    }
  }

  func apply(_ snapshot: NavigationSnapshot, search: UIButton) {
    loadViewIfNeeded()
    enabled = snapshot.presentation?.overlayOpen != true
    collectionView.isUserInteractionEnabled = enabled
    collectionView.accessibilityElementsHidden = !enabled
    selectedPath = snapshot.route.fullPath.components(separatedBy: "?")[0]
    selectedRoot = snapshot.route.rootId
    let sections = snapshot.moreMenu ?? []
    if lastRoots != snapshot.roots || lastSections != sections {
      lastRoots = snapshot.roots
      lastSections = sections
      var items = NSDiffableDataSourceSnapshot<Int, Entry>()
      items.appendSections([0])
      items.appendItems(
        lastRoots.map {
          Entry(id: "root-\($0.id)", title: $0.title, icon: $0.icon, rootID: $0.id, menuID: nil)
        }, toSection: 0)
      for (index, section) in sections.enumerated() {
        items.appendSections([index + 1])
        items.appendItems(
          section.items.map {
            Entry(id: "menu-\($0.id)", title: $0.title, icon: $0.icon, rootID: nil, menuID: $0.id)
          }, toSection: index + 1)
      }
      dataSource.apply(items, animatingDifferences: false)
    }
    synchronizeSelection()
    action?.removeFromSuperview()
    action = search
    search.accessibilityIdentifier = "native-sidebar-search"
    var config = search.configuration
    config?.title = "搜索"
    config?.imagePadding = 10
    config?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    search.configuration = config
    search.translatesAutoresizingMaskIntoConstraints = false
    actionHost.addSubview(search)
    NSLayoutConstraint.activate([
      search.leadingAnchor.constraint(equalTo: actionHost.leadingAnchor),
      search.trailingAnchor.constraint(equalTo: actionHost.trailingAnchor),
      search.topAnchor.constraint(equalTo: actionHost.topAnchor),
      search.bottomAnchor.constraint(equalTo: actionHost.bottomAnchor),
    ])
  }

  private func synchronizeSelection() {
    let matchingMenu = lastSections.flatMap(\.items).first { $0.path == selectedPath }
    let entries = dataSource.snapshot().itemIdentifiers
    let selected = entries.first {
      if let matchingMenu { return $0.menuID == matchingMenu.id }
      return $0.rootID != nil && $0.rootID == selectedRoot
    }
    for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
      collectionView.deselectItem(at: indexPath, animated: false)
    }
    if let selected, let indexPath = dataSource.indexPath(for: selected) {
      collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard enabled, let entry = dataSource.itemIdentifier(for: indexPath) else { return }
    // Do not optimistically change selection: the web permission guard must confirm the route.
    synchronizeSelection()
    if let rootID = entry.rootID { onSelectRoot?(rootID) }
    if let menuID = entry.menuID,
      let item = lastSections.flatMap(\.items).first(where: { $0.id == menuID })
    {
      onSelectMenu?(item)
    }
  }
}
