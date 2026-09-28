import * as React from 'react';

/**
 * Where the system placed the tab bar.
 *
 * `leading` and `trailing` describe a vertical bar along one side, which iOS
 * uses on devices with a vertical bar edge (iPhone Duo). They follow layout
 * direction, so map them through the layout direction — not to fixed sides —
 * when picking which safe-area inset to apply.
 */
export type TabBarPosition =
  | 'top'
  | 'bottom'
  | 'leading'
  | 'trailing'
  | undefined;

export const TabBarPositionContext =
  React.createContext<TabBarPosition>(undefined);
