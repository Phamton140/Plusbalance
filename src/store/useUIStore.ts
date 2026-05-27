import { create } from 'zustand';

interface UIState {
  isFastEntryOpen: boolean;
  openFastEntry: () => void;
  closeFastEntry: () => void;
}

export const useUIStore = create<UIState>((set) => ({
  isFastEntryOpen: false,
  openFastEntry: () => set({ isFastEntryOpen: true }),
  closeFastEntry: () => set({ isFastEntryOpen: false }),
}));
