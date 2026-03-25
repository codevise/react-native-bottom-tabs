import React

@objcMembers
public class TabBarPositionEvent: NSObject, RCTEvent {
  private var position: String
  public var viewTag: NSNumber

  public var eventName: String {
    "onTabBarPosition"
  }

  public init(reactTag: NSNumber, position: String) {
    self.viewTag = reactTag
    self.position = position
    super.init()
  }

  public class func moduleDotMethod() -> String {
    "RCTEventEmitter.receiveEvent"
  }

  public func canCoalesce() -> Bool {
    false
  }

  public func arguments() -> [Any] {
    [
      viewTag,
      RCTNormalizeInputEventName(eventName) ?? eventName,
      [
        "position": position
      ]
    ]
  }
}
