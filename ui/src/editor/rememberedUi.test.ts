import { beforeEach, describe, expect, it } from 'vitest'
import { rememberedUi, rememberedViewport } from './EditorActions'

// Needs a browser-like localStorage (the helpers are silent without one)
const storage = (globalThis as { localStorage?: Storage }).localStorage
const withStorage = storage && typeof window !== 'undefined' ? it : it.skip

describe('remembered viewport', () => {
  beforeEach(() => storage?.clear())

  withStorage('reads a viewport width or full width, and ignores anything else', () => {
    storage!.setItem('cbstudio.viewport', '768')
    expect(rememberedViewport()).toBe(768)
    storage!.setItem('cbstudio.viewport', '100%')
    expect(rememberedViewport()).toBe('100%')
    storage!.setItem('cbstudio.viewport', 'wide')
    expect(rememberedViewport()).toBeNull()
  })

  it('starts Puck with the whole viewports state when one is remembered, and leaves it alone otherwise', () => {
    const ui = rememberedUi()
    if (rememberedViewport() === null) expect(ui).not.toHaveProperty('viewports')
    else expect(ui.viewports).toMatchObject({ options: [], controlsVisible: true })
  })
})
