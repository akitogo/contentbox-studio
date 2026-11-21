import { describe, expect, it } from 'vitest'
import type { ContentDetails } from '../types'
import { sameSettings, settingsOf, settingsPayload, withCategory } from './contentSettings'
import { EMPTY_DOC, type RichTextDoc } from './richText'

const doc = (text: string): RichTextDoc => ({ type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text }] }] })
const toDoc = (html: string) => (html ? doc(html.replace(/<[^>]+>/g, '')) : EMPTY_DOC)

const content = (change: Partial<ContentDetails> = {}): ContentDetails => ({
  contentID: 'c1',
  contentType: 'entry',
  title: 'Summer',
  slug: 'summer',
  siteID: 's1',
  siteSlug: 'default',
  layout: '',
  parentID: '',
  isPublished: true,
  version: 3,
  status: 'published',
  publishedDate: '2026-11-10T10:00:00',
  expireDate: '',
  language: 'en',
  url: 'http://example.test/blog/summer',
  seo: { title: '', description: 'About summer', keywords: '' },
  entry: {
    categories: [{ categoryID: 'k1', name: 'News', slug: 'news' }],
    excerpt: '<p>Short</p>',
    featuredImage: 'disk:summer.jpg',
    featuredImageURL: '/__media/summer.jpg',
    allowComments: true,
  },
  ...change,
})

describe('settingsOf', () => {
  it('takes what an entry can change in the editor', () => {
    const settings = settingsOf(content(), { canSetLanguage: true, toDoc })
    expect(settings.language).toBe('en')
    expect(settings.seo?.description).toBe('About summer')
    expect(settings.entry).toEqual({
      publishedDate: '2026-11-10T10:00',
      expireDate: '',
      categories: [{ categoryID: 'k1', name: 'News' }],
      excerpt: doc('Short'),
      featuredImage: 'disk:summer.jpg',
      featuredImageURL: '/__media/summer.jpg',
      allowComments: true,
    })
  })

  it('leaves out what cannot be changed', () => {
    expect(settingsOf(content(), { canSetLanguage: false, toDoc }).language).toBeNull()
    const page = settingsOf(content({ contentType: 'page', entry: undefined }), { canSetLanguage: true, toDoc })
    expect(page.entry).toBeNull()
    const item = settingsOf(content({ contentType: 'contentStore', entry: undefined }), { canSetLanguage: true, toDoc })
    expect(item).toEqual({ title: 'Summer', seo: null, language: null, showInMenu: null, entry: null })
  })

  it('has the menu setting for pages only, shown unless turned off', () => {
    expect(settingsOf(content(), { canSetLanguage: true, toDoc }).showInMenu).toBeNull()
    const page = (showInMenu?: boolean) => settingsOf(content({ contentType: 'page', entry: undefined, showInMenu }), { canSetLanguage: true, toDoc })
    expect(page(false).showInMenu).toBe(false)
    expect(page(true).showInMenu).toBe(true)
    expect(page(undefined).showInMenu).toBe(true)
  })
})

describe('settingsPayload', () => {
  it('sends existing categories by id and new ones by name', () => {
    const settings = settingsOf(content(), { canSetLanguage: true, toDoc })
    settings.entry!.categories.push({ categoryID: '', name: 'Events' })
    const payload = settingsPayload({ ...settings, language: ' de ' })
    expect(payload.language).toBe('de')
    expect(payload.entry?.categories).toEqual([{ categoryID: 'k1' }, { name: 'Events' }])
    expect(payload.entry).not.toHaveProperty('featuredImageURL')
  })

  it('sends nothing that cannot be changed', () => {
    expect(settingsPayload({ title: ' Offer ', seo: null, language: null, showInMenu: null, entry: null })).toEqual({ title: 'Offer' })
  })

  it('sends the menu setting of a page, also when it is off', () => {
    expect(settingsPayload({ title: 'Offer', seo: null, language: null, showInMenu: false, entry: null })).toEqual({ title: 'Offer', showInMenu: false })
  })
})

describe('sameSettings', () => {
  it('tells changed settings from unchanged ones', () => {
    const a = settingsOf(content(), { canSetLanguage: true, toDoc })
    const b = settingsOf(content(), { canSetLanguage: true, toDoc })
    expect(sameSettings(a, b)).toBe(true)
    b.entry!.allowComments = false
    expect(sameSettings(a, b)).toBe(false)
  })
})

describe('withCategory', () => {
  const existing = [{ categoryID: 'k1', name: 'News', slug: 'news', entries: 2 }]

  it('picks an existing category by name, whatever the case', () => {
    expect(withCategory([], ' news ', existing)).toEqual([{ categoryID: 'k1', name: 'News' }])
  })

  it('adds a new category once and ignores empty names', () => {
    const once = withCategory([], 'Events', existing)
    expect(once).toEqual([{ categoryID: '', name: 'Events' }])
    expect(withCategory(once, 'events', existing)).toBe(once)
    expect(withCategory(once, '  ', existing)).toBe(once)
    expect(withCategory([{ categoryID: 'k1', name: 'News' }], 'NEWS', existing)).toHaveLength(1)
  })
})
