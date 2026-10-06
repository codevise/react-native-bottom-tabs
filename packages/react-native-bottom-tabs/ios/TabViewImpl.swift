import Foundation
import React
import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

/// SwiftUI implementation of TabView used to render React Native views.
struct TabViewImpl: View {
  @ObservedObject var props: TabViewProps
  #if os(macOS)
    @Weak var tabBar: NSTabView?
  #else
    @Weak var tabBar: UITabBar?
  #endif

  @ViewBuilder
  var tabContent: some View {
    if #available(iOS 18, macOS 15, visionOS 2, tvOS 18, *) {
      NewTabView(
        props: props,
        onLayout: onLayout,
        onSelect: onSelect
      ) {
        updateTabBarAppearance(props: props, tabBar: tabBar)
      }
    } else {
      LegacyTabView(
        props: props,
        onLayout: onLayout,
        onSelect: onSelect
      ) {
        updateTabBarAppearance(props: props, tabBar: tabBar)
      }
    }
  }

  var onSelect: (_ key: String) -> Void
  var onLongPress: (_ key: String) -> Void
  var onLayout: (_ size: CGSize) -> Void
  var onTabBarMeasured: (_ height: Int) -> Void

  var body: some View {
    tabContent
      .tabBarMinimizeBehavior(props.minimizeBehavior)
      #if !os(tvOS) && !os(macOS) && !os(visionOS)
        .onTabItemEvent { index, isLongPress in
          let item = props.filteredItems[safe: index]
          guard let key = item?.key else { return false }

          if isLongPress {
            onLongPress(key)
            emitHapticFeedback(longPress: true)
          } else {
            onSelect(key)
            emitHapticFeedback()
          }
          return item?.preventsDefault ?? false
        }
      #endif
      .introspectTabView { tabController in
        tabController.view.backgroundColor = .clear
        tabController.viewControllers?.forEach { $0.view.backgroundColor = .clear }
        #if os(macOS)
          tabBar = tabController
        #else
          tabBar = tabController.tabBar
          if !props.tabBarHidden {
            onTabBarMeasured(horizontalTabBarHeight(of: tabController))
          }
          #if os(iOS)
            VerticalBarBadges.align(in: tabController)
          #endif
        #endif
      }
      #if !os(macOS)
        .configureAppearance(props: props, tabBar: tabBar)
      #endif
      .tintColor(props.selectedActiveTintColor)
      .getSidebarAdaptable(enabled: props.sidebarAdaptable ?? false)
      .onChange(of: props.selectedPage ?? "") { newValue in
        #if !os(macOS)
          if props.disablePageAnimations {
            UIView.setAnimationsEnabled(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              UIView.setAnimationsEnabled(true)
            }
          }
        #endif
        #if os(tvOS) || os(macOS) || os(visionOS)
          onSelect(newValue)
        #endif
      }
  }

  func emitHapticFeedback(longPress: Bool = false) {
    #if os(iOS)
      if !props.hapticFeedbackEnabled {
        return
      }

      if longPress {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else {
        UISelectionFeedbackGenerator().selectionChanged()
      }
    #endif
  }
}

#if !os(macOS)
  /// The height a horizontal tab bar occupies along the bottom of the content.
  ///
  /// A vertical bar runs the full height of its container, so its frame height
  /// is the container's height — a number that means nothing to a consumer
  /// reserving space below the content, and large enough to blank out a screen
  /// if it is used as one. Report 0 in that case. The space a vertical bar takes
  /// is on a horizontal edge and is already carried by the safe-area insets.
  private func horizontalTabBarHeight(of tabController: UITabBarController) -> Int {
    let barFrame = tabController.tabBar.frame
    let container = tabController.view.bounds

    guard barFrame.width > 0, barFrame.height > 0 else {
      return Int(barFrame.height)
    }

    let spansWidth = abs(barFrame.width - container.width) < 1
    let spansHeight = abs(barFrame.height - container.height) < 1
    if spansHeight && !spansWidth {
      return 0
    }

    return Int(barFrame.height)
  }
#endif

#if !os(macOS)
  private func updateTabBarAppearance(props: TabViewProps, tabBar: UITabBar?) {
    guard let tabBar else { return }

    tabBar.isHidden = props.tabBarHidden

    if props.scrollEdgeAppearance == "transparent" {
      configureTransparentAppearance(tabBar: tabBar, props: props)
      return
    }

    configureStandardAppearance(tabBar: tabBar, props: props)
  }
#endif

#if !os(macOS)
  private func configureTransparentAppearance(tabBar: UITabBar, props: TabViewProps) {
    tabBar.barTintColor = props.barTintColor
    #if !os(visionOS)
      tabBar.isTranslucent = props.translucent
    #endif
    tabBar.unselectedItemTintColor = props.inactiveTintColor

    guard let items = tabBar.items else { return }

    let attributes = TabBarFontSize.createNormalStateAttributes(
      fontSize: props.fontSize,
      fontFamily: props.fontFamily,
      fontWeight: props.fontWeight,
      inactiveColor: nil
    )

    items.forEach { item in
      item.setTitleTextAttributes(attributes, for: .normal)
    }
  }

  private func configureStandardAppearance(tabBar: UITabBar, props: TabViewProps) {
    let appearance = UITabBarAppearance()

    // Configure background
    switch props.scrollEdgeAppearance {
    case "opaque":
      appearance.configureWithOpaqueBackground()
    default:
      appearance.configureWithDefaultBackground()
    }

    if props.translucent == false {
      appearance.configureWithOpaqueBackground()
    }

    if props.barTintColor != nil {
      appearance.backgroundColor = props.barTintColor
    }

    // Configure item appearance
    let itemAppearance = UITabBarItemAppearance()

    let attributes = TabBarFontSize.createNormalStateAttributes(
      fontSize: props.fontSize,
      fontFamily: props.fontFamily,
      fontWeight: props.fontWeight,
      inactiveColor: props.inactiveTintColor
    )

    if let inactiveTintColor = props.inactiveTintColor {
      itemAppearance.normal.iconColor = inactiveTintColor
    }

    itemAppearance.normal.titleTextAttributes = attributes

    // Active (selected) label styling — mirrors the Android tabLabelActiveStyle
    // prop. Each field falls back to the corresponding base value, so the
    // existing behavior (single style for all states) is preserved when
    // tabLabelActiveStyle is unset. iOS 26+ liquid-glass tabs ignore
    // UITabBarItemAppearance, so we skip there to keep system styling.
    if #unavailable(iOS 26.0) {
      let hasActiveOverride = props.activeFontFamily != nil
        || props.activeFontWeight != nil
        || props.activeFontSize != nil
      if hasActiveOverride {
        let selectedAttributes = TabBarFontSize.createNormalStateAttributes(
          fontSize: props.activeFontSize ?? props.fontSize,
          fontFamily: props.activeFontFamily ?? props.fontFamily,
          fontWeight: props.activeFontWeight ?? props.fontWeight,
          inactiveColor: nil
        )
        itemAppearance.selected.titleTextAttributes = selectedAttributes
        itemAppearance.focused.titleTextAttributes = selectedAttributes
      }
    }

    // Push the title down by `tabBarItemPaddingTop` so it sits further from the
    // top divider. Pairs with the per-item imageInsets shift below — without
    // both, icon and label drift apart.
    if props.tabBarItemPaddingTop >= 0 {
      let titleOffset = UIOffset(horizontal: 0, vertical: CGFloat(props.tabBarItemPaddingTop))
      itemAppearance.normal.titlePositionAdjustment = titleOffset
      itemAppearance.selected.titlePositionAdjustment = titleOffset
      itemAppearance.disabled.titlePositionAdjustment = titleOffset
    }

    // Shrink badge to a near-dot on iOS 26+ (liquid glass tab bar): SwiftUI
    // .badge(Text) always renders a pill, so we collapse it via tiny font +
    // clear text color and nudge it onto the icon. iOS 18 ignores these
    // appearance hooks for the new Tab(value:) API, so we leave the default
    // badge there.
    if #available(iOS 26.0, *) {
      let badgeAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 5),
        .foregroundColor: UIColor.clear,
      ]
      itemAppearance.normal.badgeTextAttributes = badgeAttributes
      itemAppearance.selected.badgeTextAttributes = badgeAttributes
      let badgeOffset = UIOffset(horizontal: 3, vertical: 3)
      itemAppearance.normal.badgePositionAdjustment = badgeOffset
      itemAppearance.selected.badgePositionAdjustment = badgeOffset
    }

    // Apply item appearance to all layouts
    appearance.stackedLayoutAppearance = itemAppearance
    appearance.inlineLayoutAppearance = itemAppearance
    appearance.compactInlineLayoutAppearance = itemAppearance

    // Apply final appearance
    tabBar.standardAppearance = appearance
    if #available(iOS 15.0, *) {
      tabBar.scrollEdgeAppearance = appearance.copy()
    }

    // Push the icon down by `tabBarItemPaddingTop`. UITabBarItemAppearance has
    // no icon-position knob; imageInsets must be set per item. UITabBar does
    // not relayout items on its own when imageInsets are mutated outside the
    // SwiftUI layout cycle, so force a layout pass — otherwise the new
    // padding doesn't appear until the next tab switch triggers a relayout.
    if props.tabBarItemPaddingTop >= 0, let items = tabBar.items {
      let pad = CGFloat(props.tabBarItemPaddingTop)
      let insets = UIEdgeInsets(top: pad, left: 0, bottom: -pad, right: 0)
      items.forEach { $0.imageInsets = insets }
      tabBar.setNeedsLayout()
      tabBar.layoutIfNeeded()
    }
  }
#endif

extension View {
  @ViewBuilder
  func getSidebarAdaptable(enabled: Bool) -> some View {
    if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
      if enabled {
        #if compiler(>=6.0)
          self.tabViewStyle(.sidebarAdaptable)
        #else
          self
        #endif
      } else {
        self
      }
    } else {
      self
    }
  }

  @ViewBuilder
  func tabBadge(_ data: String?) -> some View {
    if #available(iOS 15.0, macOS 15.0, visionOS 2.0, tvOS 15.0, *) {
      if let data {
        #if !os(tvOS)
          self.badge(data)
        #else
          self
        #endif
      } else {
        self
      }
    } else {
      self
    }
  }

  #if !os(macOS)
    @ViewBuilder
    func configureAppearance(props: TabViewProps, tabBar: UITabBar?) -> some View {
      self
        .onChange(of: props.barTintColor) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.scrollEdgeAppearance) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.translucent) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.inactiveTintColor) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.selectedActiveTintColor) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.fontSize) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.fontFamily) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.fontWeight) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.tabBarHidden) { newValue in
          tabBar?.isHidden = newValue
        }
        .onChange(of: props.tabBarItemPaddingTop) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.activeFontFamily) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.activeFontWeight) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
        .onChange(of: props.activeFontSize) { _ in
          updateTabBarAppearance(props: props, tabBar: tabBar)
        }
    }
  #endif

  @ViewBuilder
  func tintColor(_ color: PlatformColor?) -> some View {
    if let color {
      let color = Color(color)
      if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
        self.tint(color)
      } else {
        self.accentColor(color)
      }
    } else {
      self
    }
  }

  @ViewBuilder
  func tabBarMinimizeBehavior(_ behavior: MinimizeBehavior?) -> some View {
    #if compiler(>=6.2)
      if #available(iOS 26.0, *) {
        if let behavior {
          self.tabBarMinimizeBehavior(behavior.convert())
        } else {
          self
        }
      } else {
        self
      }
    #else
      self
    #endif
  }

  @ViewBuilder
  func hideTabBar(_ flag: Bool) -> some View {
    #if !os(macOS)
      if flag {
        if #available(iOS 16.0, tvOS 16.0, *) {
          self.toolbar(.hidden, for: .tabBar)
        } else {
          // We fallback to isHidden on UITabBar
          self
        }
      } else {
        self
      }
    #else
      self
    #endif
  }

  // Allows TabView to use unfilled SFSymbols.
  // By default they are always filled.
  @ViewBuilder
  func noneSymbolVariant() -> some View {
    if #available(iOS 15.0, tvOS 15.0, macOS 13.0, *) {
      self
        .environment(\.symbolVariants, .none)
    } else {
      self
    }
  }
}

#if os(iOS)
  /// Badge position on the vertical tab bar (iPhone Duo).
  ///
  /// The appearance's `badgePositionAdjustment` is shared by both bars, but they
  /// read it differently: the horizontal bar follows it live, while the vertical
  /// bar copies it once when it builds its items and ignores later changes. A
  /// fold or unfold passes through a horizontal bar and rebuilds the vertical one
  /// mid-transition, so no appearance value can be in place in time for it. The
  /// appearance therefore keeps the horizontal bar's offset, and the vertical
  /// bar's badges are moved by the difference here, after every rebuild.
  @MainActor
  enum VerticalBarBadges {
    /// The vertical bar centres the icon with no label under it, which puts the
    /// badge 8.5pt higher against the icon's corner than in a horizontal bar.
    /// Measured on the iOS 27.1 simulator.
    static let extraVerticalOffset: CGFloat = 8.5

    /// Whether a shift is in place. The bar reuses the same badge views when it
    /// turns horizontal, so the shift has to be taken off again then.
    private static var isShifted = false

    static func align(in tabController: UITabBarController) {
      let vertical = isVertical(tabController)
      guard vertical || isShifted, let root = tabViewRoot(of: tabController) else { return }
      let shift = vertical
        ? CATransform3DMakeTranslation(0, extraVerticalOffset, 0)
        : CATransform3DIdentity
      visit(root, insideVerticalBar: false, vertical: vertical, shift: shift)
      isShifted = vertical
    }

    /// The top of the native tab view inside React Native's hierarchy: everything
    /// above it is React Native, which is where the walk must not be pruned from.
    private static func tabViewRoot(of tabController: UITabBarController) -> UIView? {
      var root: UIView? = tabController.view
      while let parent = root?.superview, !isReactNative(parent) {
        root = parent
      }
      return root
    }

    private static func isReactNative(_ view: UIView) -> Bool {
      let name = String(describing: type(of: view))
      return name.hasPrefix("RCT") || name.hasPrefix("RNS")
    }

    /// The vertical bar spans its container's height rather than its width.
    private static func isVertical(_ tabController: UITabBarController) -> Bool {
      let bar = tabController.tabBar.frame
      let container = tabController.view.bounds
      guard bar.width > 0, bar.height > 0 else { return false }
      return abs(bar.height - container.height) < 1 && abs(bar.width - container.width) >= 1
    }

    /// The vertical bar's items live outside the `UITabBar`, in a toolbar-hosted
    /// `_UITabBarExpansionPlatterContainer`. The tabs' React Native content is
    /// skipped, as it holds no tab bar views and is most of the hierarchy.
    private static func visit(
      _ view: UIView,
      insideVerticalBar: Bool,
      vertical: Bool,
      shift: CATransform3D
    ) {
      if isReactNative(view) { return }
      let name = String(describing: type(of: view))
      let inside = insideVerticalBar || name == "_UITabBarExpansionPlatterContainer"
      // UIKit lays the badge views out by setting their `frame`, which absorbs
      // a transform on the badge itself. Their container holds every item's
      // badge, so move the whole set through its sublayer transform instead.
      // Taking the shift off covers every container, wherever the bar put it.
      if name == "BadgeContainerView", inside || !vertical {
        view.layer.sublayerTransform = shift
        return
      }
      view.subviews.forEach {
        visit($0, insideVerticalBar: inside, vertical: vertical, shift: shift)
      }
    }
  }
#endif
