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

export interface EntryCategory {
  categoryID: string
  name: string
  slug: string
}

/** An entry of GET /sites/:site/entries */
export interface BlogEntry {
  contentID: string
  title: string
  slug: string
  status: PageStatus
  isPublished: boolean
  publishedDate: string
  expireDate: string
  author: string
  categories: EntryCategory[]
  hasBlocks: boolean
  language: string
  translationGroup: string
  url: string
}

/** GET /sites/:site/entries */
export interface BlogEntryList {
  entries: BlogEntry[]
  total: number
  offset: number
  max: number
}

/** GET /sites/:site/categories */
export interface BlogCategory extends EntryCategory {
  /** Number of entries in it */
  entries: number
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

/** A field of a block type (block.json, normalized by the server) */
export interface FieldDefinition {
  name: string
  type:
    | 'text'
    | 'textarea'
    | 'richtext'
    | 'number'
    | 'boolean'
    | 'select'
    | 'link'
    | 'image'
    | 'images'
    | 'html'
    | 'contentStore'
    | 'list'
  label: string
  help: string
  required: boolean
  default: unknown
  options?: { value: string; label: string }[]
  fields?: FieldDefinition[]
  /** Shown only when every named field (select or boolean) has one of the values ("true"/"false" for booleans) */
  when?: Record<string, string[]>
  maxLength?: number
  maxItems?: number
  min?: number
  max?: number
}

/** GET /blocks */
export interface BlockDefinition {
  name: string
  label: string
  description: string
  icon: string
  category: string
  version: number
  source: 'core' | 'module' | 'theme'
  fields: FieldDefinition[]
}

/** ContentBox's HTML title, meta description and keywords */
export interface Seo {
  title: string
  description: string
  keywords: string
}

export interface ContentDetails {
  contentID: string
  contentType: 'page' | 'entry' | 'contentStore'
  title: string
  slug: string
  siteID: string
  siteSlug: string
  layout: string
  parentID: string
  isPublished: boolean
  version: number
  url: string
  seo: Seo
}

/** GET /content/:id and PUT /content/:id/blocks */
export interface EditorContent {
  content: ContentDetails
  blocks: import('./blocks/format').ParsedBlock[]
  canEdit: boolean
  canEditHtml: boolean
}

export interface BlockError {
  blockID: string
  field: string
  message: string
}

export interface VersionInfo {
  versionID: string
  version: number
  isActive: boolean
  createdDate: string
  changelog: string
  author: string
}

export interface MediaFile {
  name: string
  path: string
  url: string
  size: number
  modified: string
  isImage: boolean
}

/** GET /media */
export interface MediaListing {
  folder: string
  parent: string
  folders: { name: string; path: string }[]
  files: MediaFile[]
}

/** GET /sites/:site/templates */
export interface TemplateInfo {
  templateID: string
  name: string
  description: string
  hasBlocks: boolean
}
