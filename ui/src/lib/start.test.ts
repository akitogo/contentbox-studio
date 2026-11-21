import { beforeEach, describe, expect, it } from 'vitest'
import type { Site, TreePage } from '../types'
import { rememberContent, rememberedContent, startContent } from './start'

const site = (change: Partial<Site> = {}): Site => ({ siteID: 's1', slug: 'default', name: 'Site', siteRoot: '', isBlogEnabled: true, homepage: 'home', copiedFrom: '', ...change })
const page = (contentID: string, slug: string, parentID = '', order = 1) => ({ contentID, slug, parentID, order }) as TreePage
const pages = [page('about', 'about', '', 1), page('home', 'home', '', 2), page('team', 'about/team', 'about', 1)]

describe('startContent', () => {
  it('opens the page or entry last edited', () => {
    expect(startContent(site(), pages, { contentID: 'team', contentType: 'page' })).toBe('team')
    expect(startContent(site(), pages, { contentID: 'post', contentType: 'entry' })).toBe('post')
  })

  it('falls back to the home page when the last one is gone or the blog is off', () => {
    expect(startContent(site(), pages, { contentID: 'deleted', contentType: 'page' })).toBe('home')
    expect(startContent(site({ isBlogEnabled: false }), pages, { contentID: 'post', contentType: 'entry' })).toBe('home')
    expect(startContent(site(), pages, null)).toBe('home')
  })

  it('takes the first top-level page without a home page, and nothing without pages', () => {
    expect(startContent(site({ homepage: 'cbBlog' }), pages, null)).toBe('about')
    expect(startContent(site(), [], null)).toBeNull()
  })
})

describe('rememberedContent', () => {
  beforeEach(() => globalThis.localStorage?.clear())

  it('reads back what was remembered, per site, and ignores anything else', () => {
    if (!globalThis.localStorage) return
    rememberContent('s1', { contentID: 'team', contentType: 'page' })
    expect(rememberedContent('s1')).toEqual({ contentID: 'team', contentType: 'page' })
    expect(rememberedContent('s2')).toBeNull()
    localStorage.setItem('cbstudio.lastContent.s3', '{"contentID":1}')
    expect(rememberedContent('s3')).toBeNull()
  })
})
