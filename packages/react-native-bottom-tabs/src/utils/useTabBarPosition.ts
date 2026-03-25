import { useContext } from 'react';
import { TabBarPositionContext, type TabBarPosition } from './TabBarPositionContext';

export function useTabBarPosition(): TabBarPosition {
  return useContext(TabBarPositionContext);
}
