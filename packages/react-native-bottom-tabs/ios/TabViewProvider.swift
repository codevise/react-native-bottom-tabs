import Foundation
import React
import SwiftUI

@objcMembers
public final class TabInfo: NSObject {
  public let key: String
  public let title: String
  public let badge: String?
  public let sfSymbol: String
  public let activeTintColor: PlatformColor?
  public let hidden: Bool
  public let testID: String?
  public let role: TabBarRole?
  public let preventsDefault: Bool

  public init(
    key: String,
    title: String,
    badge: String?,
    sfSymbol: String,
    activeTintColor: PlatformColor?,
    hidden: Bool,
    testID: String?,
    role: String?,
    preventsDefault: Bool = false
  ) {
    self.key = key
    self.title = title
    self.badge = badge
    self.sfSymbol = sfSymbol
    self.activeTintColor = activeTintColor
    self.hidden = hidden
    self.testID = testID
    self.role = TabBarRole(rawValue: role ?? "")
    self.preventsDefault = preventsDefault
    super.init()
  }
}

@objc public protocol TabViewProviderDelegate {
  func onPageSelected(key: String, reactTag: NSNumber?)
  func onLongPress(key: String, reactTag: NSNumber?)
  func onTabBarMeasured(height: Int, reactTag: NSNumber?)
  func onLayout(size: CGSize, reactTag: NSNumber?)
  func onTabBarPosition(position: String, reactTag: NSNumber?)
}

@objc public class TabViewProvider: PlatformView {
  private var imageLoader: RCTImageLoaderProtocol?
  private weak var delegate: TabViewProviderDelegate?
  private var props = TabViewProps()
  private var hostingController: PlatformHostingController<TabViewImpl>?
  private var coalescingKey: UInt16 = 0
  private var iconSize = CGSize(width: 27, height: 27)

  @objc var onPageSelected: RCTDirectEventBlock?

  @objc var onTabLongPress: RCTDirectEventBlock?
  @objc var onTabBarMeasured: RCTDirectEventBlock?
  @objc var onNativeLayout: RCTDirectEventBlock?
  @objc var onTabBarPosition: RCTDirectEventBlock?

  @objc public var icons: NSArray? {
    didSet {
      loadIcons(icons)
    }
  }

  @objc public var sidebarAdaptable: Bool = false {
    didSet {
      props.sidebarAdaptable = sidebarAdaptable
    }
  }

  @objc public var disablePageAnimations: Bool = false {
    didSet {
      props.disablePageAnimations = disablePageAnimations
    }
  }

  @objc public var labeled: Bool = false {
    didSet {
      props.labeled = labeled
    }
  }

  @objc public var selectedPage: NSString? {
    didSet {
      props.selectedPage = selectedPage as? String
    }
  }

  @objc public var hapticFeedbackEnabled: Bool = false {
    didSet {
      props.hapticFeedbackEnabled = hapticFeedbackEnabled
    }
  }

  @objc public var scrollEdgeAppearance: NSString? {
    didSet {
      props.scrollEdgeAppearance = scrollEdgeAppearance as? String
    }
  }

  @objc public var minimizeBehavior: NSString? {
    didSet {
      props.minimizeBehavior = MinimizeBehavior(rawValue: minimizeBehavior as? String ?? "")
    }
  }

  @objc public var translucent: Bool = true {
    didSet {
      props.translucent = translucent
    }
  }

  @objc var items: NSArray? {
    didSet {
      props.items = parseTabData(from: items)
    }
  }

  @objc public var barTintColor: PlatformColor? {
    didSet {
      props.barTintColor = barTintColor
    }
  }

  @objc public var activeTintColor: PlatformColor? {
    didSet {
      props.activeTintColor = activeTintColor
    }
  }

  @objc public var inactiveTintColor: PlatformColor? {
    didSet {
      props.inactiveTintColor = inactiveTintColor
    }
  }

  @objc public var fontFamily: NSString? {
    didSet {
      props.fontFamily = fontFamily as? String
    }
  }

  @objc public var fontWeight: NSString? {
    didSet {
      props.fontWeight = fontWeight as? String
    }
  }

  @objc public var fontSize: NSNumber? {
    didSet {
      props.fontSize = fontSize as? Int
    }
  }

  @objc public var activeFontFamily: NSString? {
    didSet {
      props.activeFontFamily = activeFontFamily as? String
    }
  }

  @objc public var activeFontWeight: NSString? {
    didSet {
      props.activeFontWeight = activeFontWeight as? String
    }
  }

  @objc public var activeFontSize: NSNumber? {
    didSet {
      // -1 (default from codegen WithDefault<Int32, -1>) means unset.
      if let value = activeFontSize?.intValue, value >= 0 {
        props.activeFontSize = value
      } else {
        props.activeFontSize = nil
      }
    }
  }

  @objc public var tabBarHidden: Bool = false {
    didSet {
      props.tabBarHidden = tabBarHidden
    }
  }

  @objc public var tabBarItemPaddingTop: NSNumber? {
    didSet {
      props.tabBarItemPaddingTop = tabBarItemPaddingTop?.intValue ?? -1
    }
  }

  // New arch specific properties

  @objc public var itemsData: [TabInfo] = [] {
    didSet {
      props.items = itemsData
    }
  }

  @objc public convenience init(delegate: TabViewProviderDelegate) {
    self.init()
    self.delegate = delegate
  }
  
  @objc public func setImageLoader(_ imageLoader: RCTImageLoader) {
    self.imageLoader = imageLoader
    loadIcons(icons)
  }

  override public func didUpdateReactSubviews() {
    props.children = reactSubviews().map(IdentifiablePlatformView.init)
  }

#if os(macOS)
  override public func layout() {
    super.layout()
    setupView()
  }
#else
  override public func layoutSubviews() {
    super.layoutSubviews()
    setupView()
    // The position is read from the tab bar's frame, and neither registered
    // trait fires when only that frame moves: the bar can change sides while
    // the size class and the vertical bar edge both stay put. The first emit
    // also runs before SwiftUI has built the tab bar controller, so there is no
    // frame to read yet and the trait answers instead. Re-resolving on every
    // layout covers both; `emitTabBarPosition` drops anything unchanged.
    emitTabBarPosition()
  }
#endif

  private func setupView() {
    if self.hostingController != nil {
      return
    }

    self.hostingController = PlatformHostingController(rootView: TabViewImpl(props: props) { key in
      self.delegate?.onPageSelected(key: key, reactTag: self.reactTag)
    } onLongPress: { key in
      self.delegate?.onLongPress(key: key, reactTag: self.reactTag)
    } onLayout: { size  in
      self.delegate?.onLayout(size: size, reactTag: self.reactTag)
    } onTabBarMeasured: { height in
      self.delegate?.onTabBarMeasured(height: height, reactTag: self.reactTag)
    })

    if let hostingController = self.hostingController, let parentViewController = reactViewController() {
      parentViewController.addChild(hostingController)
      hostingController.view.backgroundColor = .clear
      addSubview(hostingController.view)
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      hostingController.view.pinEdges(to: self)
#if !os(macOS)
      hostingController.didMove(toParent: parentViewController)
#endif
    }
  }

  private var lastEmittedTabBarPosition: String?

  #if !os(macOS)
  override public func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      emitTabBarPosition()
      if #available(iOS 17.0, *) {
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: TabViewProvider, _: UITraitCollection) in
          self.emitTabBarPosition()
        }
      }
      if #available(iOS 27.1, *) {
        // The vertical bar edge changes without a size-class change — moving the
        // window across a split-view divider flips it at constant width — so the
        // size-class registration above cannot see it.
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (self: TabViewProvider, _: UITraitCollection) in
          self.emitTabBarPosition()
        }
      }
    }
  }

  // Fallback for iOS < 17
  override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #unavailable(iOS 17.0) {
      if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
        emitTabBarPosition()
      }
    }
  }

  private func emitTabBarPosition() {
    let position = resolvedTabBarPosition()
    guard position != lastEmittedTabBarPosition else { return }

    lastEmittedTabBarPosition = position
    delegate?.onTabBarPosition(position: position, reactTag: reactTag)
  }

  /// Where the system placed the tab bar.
  ///
  /// A resolved vertical bar edge is authoritative: the bar runs along that side
  /// and is not a horizontal bar at all. `unspecified` covers both "no vertical
  /// bar is possible here" and "one is allowed but the edge is unresolved", so
  /// it falls through to the horizontal inference rather than being trusted.
  private func resolvedTabBarPosition() -> String {
    if let measured = measuredTabBarPosition() {
      return measured
    }

    if #available(iOS 27.1, *) {
      switch traitCollection.verticalBarEdge {
      case .leading: return "leading"
      case .trailing: return "trailing"
      case .unspecified: break
      @unknown default: break
      }
    }

    let isRegularWidth = traitCollection.horizontalSizeClass == .regular
    var tabsCanBeAtTop = false
    if #available(iOS 18.0, *) {
      tabsCanBeAtTop = true
    }
    return (isRegularWidth && tabsCanBeAtTop) ? "top" : "bottom"
  }

  /// Where the tab bar sits, read from its own frame.
  ///
  /// Authoritative once the bar has been laid out, and the only signal that
  /// separates a bottom bar from a top bar in a regular width — neither the
  /// size class nor the vertical bar edge can, since both report the same
  /// values for a tablet and for a large phone display holding a bottom bar.
  ///
  /// `nil` before the first layout, where the frame is empty and says nothing.
  private func measuredTabBarPosition() -> String? {
    guard let tabController = tabBarController(under: hostingController) else { return nil }

    let bar = tabController.tabBar.frame
    let container = tabController.view.bounds
    guard bar.width > 0, bar.height > 0, container.width > 0, container.height > 0
    else { return nil }

    let spansWidth = abs(bar.width - container.width) < 1
    let spansHeight = abs(bar.height - container.height) < 1

    if spansWidth && !spansHeight {
      return bar.minY > container.midY ? "bottom" : "top"
    }

    if spansHeight && !spansWidth {
      // The reported edge follows layout direction, while the frame is physical.
      let isRightToLeft = traitCollection.layoutDirection == .rightToLeft
      let sitsOnTheRight = bar.minX > container.midX
      return (sitsOnTheRight != isRightToLeft) ? "trailing" : "leading"
    }

    return nil
  }

  /// The `UITabBarController` SwiftUI created for the `TabView`, which is a
  /// descendant of the hosting controller rather than something we are handed.
  private func tabBarController(under controller: UIViewController?) -> UITabBarController? {
    guard let controller else { return nil }
    if let tabController = controller as? UITabBarController { return tabController }

    for child in controller.children {
      if let found = tabBarController(under: child) { return found }
    }
    return nil
  }
  #endif

  @objc(insertChild:atIndex:)
  public func insertChild(_ child: UIView, at index: Int) {
    guard index >= 0 && index <= props.children.count else {
      return
    }
    props.children.insert(IdentifiablePlatformView(child), at: index)
  }

  @objc(removeChildAtIndex:)
  public func removeChild(at index: Int) {
    guard index >= 0 && index < props.children.count else {
      return
    }
    props.children.remove(at: index)
  }

  private func loadIcons(_ icons: NSArray?) {
    guard let imageLoader else { return }
    
    // TODO: Diff the arrays and update only changed items.
    // Now if the user passes `unfocusedIcon` we update every item.
    if let imageSources = icons as? [RCTImageSource?] {
      for (index, imageSource) in imageSources.enumerated() {
        guard let imageSource else { continue }
        imageLoader.loadImage(
          with: imageSource.request,
          size: imageSource.size,
          scale: imageSource.scale,
          clipped: true,
          resizeMode: RCTResizeMode.contain,
          progressBlock: { _,_ in },
          partialLoad: { _ in },
          completionBlock: { error, image in
            if error != nil {
              print("[TabView] Error loading image: \(error!.localizedDescription)")
              return
            }
            guard let image else { return }
            DispatchQueue.main.async { [weak self] in
              guard let self else { return }
              self.props.icons[index] = image.resizeImageTo(size: self.iconSize)
            }
          })
      }
    }
  }

  private func parseTabData(from array: NSArray?) -> [TabInfo] {
    guard let array else { return [] }
    var items: [TabInfo] = []

    for value in array {
      if let itemDict = value as? [String: Any] {
        items.append(
          TabInfo(
            key: itemDict["key"] as? String ?? "",
            title: itemDict["title"] as? String ?? "",
            badge: itemDict["badge"] as? String,
            sfSymbol: itemDict["sfSymbol"] as? String ?? "",
            activeTintColor: RCTConvert.uiColor(itemDict["activeTintColor"] as? NSNumber),
            hidden: itemDict["hidden"] as? Bool ?? false,
            testID: itemDict["testID"] as? String ?? "",
            role: itemDict["role"] as? String,
            preventsDefault: itemDict["preventsDefault"] as? Bool ?? false
          )
        )
      }
    }

    return items
  }
}
