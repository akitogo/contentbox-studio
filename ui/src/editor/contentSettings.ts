/**
 * The content's settings as the editor edits them (right column, no block selected): search engine fields, language,
 * for pages whether they appear in the menu, and for blog entries publish dates, categories, excerpt, featured image and comments. They are saved with the
 * blocks (PUT /content/:id/blocks), so Save, the unsaved marker and the leave warning cover them.
 */
import { generateJSON } from '@tiptap/react'
import type { BlogCategory, ContentDetails, Seo } from '../types'
import { EMPTY_DOC, richTextExtensions, type RichTextDoc } from './richText'

/** A category of the entry: an existing one, or a new one (no id yet) that the save creates */
export interface CategoryChoice {
  categoryID: string
  name: string
}

export interface EntryEdit {
  /** yyyy-mm-ddTHH:mm, as <input type="datetime-local"> takes it; "" for none */
  publishedDate: string
  expireDate: string
  categories: CategoryChoice[]
  excerpt: RichTextDoc
  /** As stored, sent back unchanged unless another image is chosen */
  featuredImage: string
  featuredImageURL: string
  allowComments: boolean
}

export interface ContentSettings {
  /** The content's title (edited in the canvas header of blog entries) */
  title: string
  /** null for content store items (no page of their own) */
  seo: Seo | null
  /** null when it cannot be changed here (content store items, or no STUDIO_SITE_TREE permission) */
  language: string | null
  /** null for blog entries and content store items (only pages are in the menu) */
  showInMenu: boolean | null
  entry: EntryEdit | null
}

/** HTML (an entry's excerpt) as a rich text document; needs a browser (DOMParser) */
export function htmlToDoc(html: string): RichTextDoc {
  return html.trim() ? (generateJSON(html, richTextExtensions()) as RichTextDoc) : EMPTY_DOC
}

/** An API date (yyyy-mm-ddTHH:nn:ss) for a datetime-local input */
export const toLocalInput = (value: string) => value.slice(0, 16)

export function settingsOf(
  content: ContentDetails,
  { canSetLanguage, toDoc = htmlToDoc }: { canSetLanguage: boolean; toDoc?: (html: string) => RichTextDoc },
): ContentSettings {
  const hasPage = content.contentType !== 'contentStore'
  const entry = content.entry
  return {
    title: content.title,
    seo: hasPage ? { ...content.seo } : null,
    language: hasPage && canSetLanguage ? content.language : null,
    showInMenu: content.contentType === 'page' ? content.showInMenu !== false : null,
    entry: entry
      ? {
          publishedDate: toLocalInput(content.publishedDate),
          expireDate: toLocalInput(content.expireDate),
          categories: entry.categories.map(({ categoryID, name }) => ({ categoryID, name })),
          excerpt: toDoc(entry.excerpt),
          featuredImage: entry.featuredImage,
          featuredImageURL: entry.featuredImageURL,
          allowComments: entry.allowComments,
        }
      : null,
  }
}

export const sameSettings = (a: ContentSettings, b: ContentSettings) => JSON.stringify(a) === JSON.stringify(b)

/** The settings' part of the save request: only what can be changed here */
export function settingsPayload(settings: ContentSettings) {
  const { title, seo, language, showInMenu, entry } = settings
  return {
    title: title.trim(),
    ...(seo ? { seo } : {}),
    ...(language !== null ? { language: language.trim() } : {}),
    ...(showInMenu !== null ? { showInMenu } : {}),
    ...(entry
      ? {
          entry: {
            publishedDate: entry.publishedDate,
            expireDate: entry.expireDate,
            categories: entry.categories.map(({ categoryID, name }) => (categoryID ? { categoryID } : { name })),
            excerpt: entry.excerpt,
            featuredImage: entry.featuredImage,
            allowComments: entry.allowComments,
          },
        }
      : {}),
  }
}

/**
 * The categories with one more, by name: an existing category of the site if one has that name (case-insensitive),
 * else a new one; unchanged if the name is empty or already chosen
 */
export function withCategory(chosen: CategoryChoice[], name: string, existing: BlogCategory[]): CategoryChoice[] {
  const trimmed = name.trim()
  if (!trimmed) return chosen
  const match = existing.find((category) => category.name.toLowerCase() === trimmed.toLowerCase())
  const choice = match ? { categoryID: match.categoryID, name: match.name } : { categoryID: '', name: trimmed }
  const same = (item: CategoryChoice) => (choice.categoryID ? item.categoryID === choice.categoryID : !item.categoryID && item.name.toLowerCase() === trimmed.toLowerCase())
  return chosen.some(same) ? chosen : [...chosen, choice]
}
