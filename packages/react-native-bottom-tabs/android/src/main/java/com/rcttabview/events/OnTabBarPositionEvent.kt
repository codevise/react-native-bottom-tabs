package com.rcttabview.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter

class OnTabBarPositionEvent(viewTag: Int, private val position: String) :
  Event<OnTabBarPositionEvent>(viewTag) {

  companion object {
    const val EVENT_NAME = "onTabBarPosition"
  }

  override fun getEventName(): String {
    return EVENT_NAME
  }

  override fun dispatch(rctEventEmitter: RCTEventEmitter) {
    val event = Arguments.createMap().apply {
      putString("position", position)
    }
    rctEventEmitter.receiveEvent(viewTag, eventName, event)
  }
}
