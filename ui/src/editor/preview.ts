/**
 * Full-page preview through ContentBox's own preview (/__page_preview, /__entry_preview): it renders the posted body
 * with the site's theme and layout. It needs the classic admin session (the Studio page has it) and the hash of the
 * author id (config.previewHash).
 */
import type { StudioConfig } from '../config'
import type { ContentDetails } from '../types'

export const PREVIEW_WINDOW = 'cbstudio-preview'

/** Form fields ContentBox's preview handler reads; it url-decodes the content */
export function previewFields(config: StudioConfig, content: ContentDetails, body: string): Record<string, string> {
  return {
    content: encodeURIComponent(body),
    contentType: content.contentType,
    layout: content.layout,
    title: content.title,
    slug: content.slug,
    h: config.previewHash,
    siteID: content.siteID,
    markup: 'HTML',
    parentContent: content.parentID,
  }
}

export function previewUrl(config: StudioConfig, content: ContentDetails): string | null {
  if (content.contentType === 'page') return config.pagePreview
  if (content.contentType === 'entry') return config.entryPreview
  return null
}

/** POST the fields to the preview URL in a separate window */
export function openPreview(url: string, fields: Record<string, string>) {
  const form = document.createElement('form')
  form.method = 'POST'
  form.action = url
  form.target = PREVIEW_WINDOW
  for (const [name, value] of Object.entries(fields)) {
    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = name
    input.value = value
    form.appendChild(input)
  }
  document.body.appendChild(form)
  form.submit()
  form.remove()
}
