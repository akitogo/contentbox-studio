/** Shapes of the Studio API (modules/contentbox-studio-api) */

export interface Me {
  authorID: string
  username: string
  name: string
  email: string
  role: string
  permissions: { siteTree: boolean; htmlBlocks: boolean }
}

export interface Site {
  siteID: string
  slug: string
  name: string
  siteRoot: string
}

export type PageStatus = 'published' | 'draft' | 'scheduled' | 'expired'

/** GET /sites/:site/tree */
export interface TreePage {
  contentID: string
  parentID: string
  title: string
  slug: string
  order: number
  status: PageStatus
  isPublished: boolean
  publishedDate: string
  expireDate: string
  showInMenu: boolean
  hasBlocks: boolean
  language: string
  translationGroup: string
  url: string
}

export interface TranslationMember {
  contentID: string
  title: string
  slug: string
  contentType: string
  siteID: string
  siteName: string
  language: string
  url: string
  isCurrent: boolean
}

/** GET /content/:id/translations */
export interface TranslationGroup {
  contentID: string
  language: string
  group: string
  members: TranslationMember[]
}
