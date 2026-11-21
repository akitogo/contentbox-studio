import { describe, expect, it } from 'vitest'
import type { StudioConfig } from '../config'
import type { ContentDetails } from '../types'
import { previewFields, previewUrl } from './preview'

const config = { previewHash: 'h1', pagePreview: '/__page_preview', entryPreview: '/__entry_preview' } as StudioConfig
const content = (change: Partial<ContentDetails>) =>
  ({ contentType: 'page', layout: 'pages', title: 'About', slug: 'about', siteID: 's1', parentID: '', ...change }) as ContentDetails

describe('previewFields', () => {
  it("previews pages in their own layout and entries in the theme's blog layout", () => {
    expect(previewFields(config, content({}), '<p>x</p>').layout).toBe('pages')
    expect(previewFields(config, content({ contentType: 'entry', layout: '' }), '<p>x</p>').layout).toBe('blog')
  })

  it('sends the body url-encoded with the hash and site', () => {
    const fields = previewFields(config, content({}), '<p>a & b</p>')
    expect(fields.content).toBe(encodeURIComponent('<p>a & b</p>'))
    expect(fields.h).toBe('h1')
    expect(fields.siteID).toBe('s1')
  })
})

describe('previewUrl', () => {
  it('has a preview for pages and entries only', () => {
    expect(previewUrl(config, content({}))).toBe('/__page_preview')
    expect(previewUrl(config, content({ contentType: 'entry' }))).toBe('/__entry_preview')
    expect(previewUrl(config, content({ contentType: 'contentStore' }))).toBeNull()
  })
})
