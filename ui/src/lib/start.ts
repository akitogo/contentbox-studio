/**
 * What Studio opens first: the site last worked on, and on a site the page or blog entry last edited there (both
 * remembered per browser), else the site's home page, else its first page
 */
import type { Site, TreePage } from '../types'
import { store, stored } from './storage'

export interface LastContent {
  contentID: string
  contentType: 'page' | 'entry'
}

const key = (siteID: string) => `cbstudio.lastContent.${siteID}`
const SITE_KEY = 'cbstudio.lastSite'

export function rememberContent(siteID: string, content: LastContent) {
  store(key(siteID), JSON.stringify(content))
  store(SITE_KEY, siteID)
}

/** Id of the site last worked on, if any */
export const rememberedSite = () => stored(SITE_KEY)

export function rememberedContent(siteID: string): LastContent | null {
  try {
    const value: unknown = JSON.parse(stored(key(siteID)) ?? 'null')
    if (value && typeof value === 'object' && 'contentID' in value && 'contentType' in value) {
      const { contentID, contentType } = value as LastContent
      if (typeof contentID === 'string' && (contentType === 'page' || contentType === 'entry')) return { contentID, contentType }
    }
  } catch {
    // not remembered
  }
  return null
}

/** The content id to open, or null when the site has nothing to open (no pages, nothing remembered) */
export function startContent(site: Site, pages: TreePage[], last: LastContent | null): string | null {
  if (last) {
    // A page only if it is still there; an entry only while the site has a blog
    const available = last.contentType === 'page' ? pages.some((page) => page.contentID === last.contentID) : site.isBlogEnabled
    if (available) return last.contentID
  }
  const home = pages.find((page) => page.slug === site.homepage)
  if (home) return home.contentID
  const first = pages.filter((page) => !page.parentID).sort((a, b) => a.order - b.order)[0]
  return first?.contentID ?? null
}
