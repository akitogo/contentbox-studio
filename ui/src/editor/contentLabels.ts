import type { ContentDetails } from '../types'

type ContentType = ContentDetails['contentType']

/** What a content item is, e.g. Puck's title for it in the fields panel */
export const CONTENT_LABELS: Record<ContentType, string> = { page: 'Page', entry: 'Blog entry', contentStore: 'Content store item' }

/** What a template of a content type is for (plural, lower case) */
export const TEMPLATE_TARGETS: Record<ContentType, string> = { page: 'pages', entry: 'blog entries', contentStore: 'content store items' }
