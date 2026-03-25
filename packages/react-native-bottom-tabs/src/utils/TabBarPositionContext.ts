import * as React from 'react';

export type TabBarPosition = 'top' | 'bottom' | undefined;

export const TabBarPositionContext = React.createContext<TabBarPosition>(undefined);
