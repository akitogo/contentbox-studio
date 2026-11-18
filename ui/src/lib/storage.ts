/**
 * Per-viewer layout memory in localStorage (column widths, hidden columns). Studio works without it: private
 * windows or blocked storage just do not remember the layout.
 */
export function stored(key: string): string | null {
  try {
    return window.localStorage.getItem(key)
  } catch {
    return null
  }
}

export function store(key: string, value: string) {
  try {
    window.localStorage.setItem(key, value)
  } catch {
    // not remembered
  }
}
