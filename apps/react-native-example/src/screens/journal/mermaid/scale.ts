import { createContext, useContext } from 'react';

// How much taller than on the page a chart draws, as when lifted into the
// lightbox, where it is also wider.
export const ChartScale = createContext(1);

export function useChartScale() {
  return useContext(ChartScale);
}
