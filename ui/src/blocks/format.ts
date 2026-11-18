/**
 * Block format, version 1: blocks as HTML comments with JSON data inside the content body.
 * Specification: docs/block-format.md. CFML counterpart: models/blocks/BlockFormat.cfc.
 */

export type BlockStatus = 'ok' | 'modified' | 'invalid' | 'legacy'

export type BlockData = Record<string, unknown>

/** A block read from a body */
export interface ParsedBlock {
  type: string
  /** Version of the block type's data */
  v: number
  id: string
  /** Field values; for html blocks `{ html }` */
  data: BlockData
  /** Inner HTML as stored */
  html: string
  status: BlockStatus
}

/** A block to write: data plus the HTML it rendered to */
export interface BlockToWrite {
  type: string
  v?: number
  id: string
  data: BlockData
  html: string
}

export const TYPE_PATTERN = /^[A-Za-z][A-Za-z0-9_-]*$/
export const ID_PATTERN = /^[A-Za-z0-9_-]{1,32}$/

const OPEN_MARKER = /<!--\s*cb:block\s+([^>]*?)\s*-->/g
const CLOSE_MARKER = /<!--\s*\/cb:block\s*-->/g
const EDGE_WHITESPACE = /^[ \t\r\n]+|[ \t\r\n]+$/g
const MARKER_LIKE = /<!--(\s*\/?)cb:block/g

/** Renames marker-like comments inside block HTML (`cb:block` -> `cb-block`) so blocks cannot nest */
export function neutralizeMarkers(html: string): string {
  return html.replace(MARKER_LIKE, '<!--$1cb-block')
}

/** Java String.hashCode of the text as 8 lowercase hex digits (unsigned) */
export function hashHtml(html: string): string {
  let hash = 0
  for (let i = 0; i < html.length; i++) {
    hash = (Math.imul(31, hash) + html.charCodeAt(i)) | 0
  }
  return (hash >>> 0).toString(16).padStart(8, '0')
}

/** JSON for the opening marker: nothing that ends the comment or triggers ContentBox's renderers */
export function escapeEnvelope(json: string): string {
  return json
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/--/g, '\\u002d\\u002d')
    .replace(/\{\{/g, '\\u007b\\u007b')
}

export function serializeBody(blocks: BlockToWrite[]): string {
  return blocks
    .map((block) => {
      const html = neutralizeMarkers(block.html)
      const envelope = {
        type: block.type,
        v: block.v ?? 1,
        id: block.id,
        hash: hashHtml(html),
        data: block.type === 'html' ? {} : block.data,
      }
      return `<!-- cb:block ${escapeEnvelope(JSON.stringify(envelope))} -->\n${html}\n<!-- /cb:block -->`
    })
    .join('\n\n')
}

export function parseBody(body: string): ParsedBlock[] {
  const blocks: ParsedBlock[] = []
  let generatedIds = 0
  const nextId = () => `legacy-${++generatedIds}`

  const asHtmlBlock = (html: string, status: 'legacy' | 'invalid'): ParsedBlock => ({
    type: 'html',
    v: 1,
    id: nextId(),
    data: { html },
    html,
    status,
  })

  const addOutsideText = (text: string) => {
    const html = text.replace(EDGE_WHITESPACE, '')
    if (html) {
      blocks.push(asHtmlBlock(html, 'legacy'))
    }
  }

  let position = 0
  while (position < body.length) {
    const open = find(OPEN_MARKER, body, position)
    if (!open) {
      addOutsideText(body.slice(position))
      break
    }
    addOutsideText(body.slice(position, open.index))

    const close = find(CLOSE_MARKER, body, open.end)
    const nextOpen = find(OPEN_MARKER, body, open.end)
    if (!close || (nextOpen && nextOpen.index < close.index)) {
      blocks.push(asHtmlBlock(body.slice(open.index).replace(EDGE_WHITESPACE, ''), 'legacy'))
      break
    }

    const html = innerHtml(body.slice(open.end, close.index))
    blocks.push(readBlock(open.json, html) ?? asHtmlBlock(html, 'invalid'))
    position = close.end
  }

  return blocks
}

interface Match {
  index: number
  end: number
  json: string
}

function find(pattern: RegExp, text: string, from: number): Match | null {
  pattern.lastIndex = from
  const match = pattern.exec(text)
  return match ? { index: match.index, end: match.index + match[0].length, json: match[1] ?? '' } : null
}

/** Without one line break after the opening and one before the closing marker */
function innerHtml(raw: string): string {
  let html = raw
  if (html.startsWith('\r\n')) html = html.slice(2)
  else if (html.startsWith('\n')) html = html.slice(1)
  if (html.endsWith('\r\n')) html = html.slice(0, -2)
  else if (html.endsWith('\n')) html = html.slice(0, -1)
  return html
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function readBlock(json: string, html: string): ParsedBlock | null {
  let envelope: unknown
  try {
    envelope = JSON.parse(json)
  } catch {
    return null
  }
  if (
    !isRecord(envelope) ||
    typeof envelope.type !== 'string' ||
    !TYPE_PATTERN.test(envelope.type) ||
    typeof envelope.id !== 'string' ||
    !ID_PATTERN.test(envelope.id)
  ) {
    return null
  }

  const data: BlockData = isRecord(envelope.data) ? { ...envelope.data } : {}
  if (envelope.type === 'html') {
    data.html = html
  }
  const v = typeof envelope.v === 'number' && Number.isInteger(envelope.v) && envelope.v > 0 ? envelope.v : 1
  const modified = typeof envelope.hash === 'string' && envelope.hash !== hashHtml(html)

  return { type: envelope.type, v, id: envelope.id, data, html, status: modified ? 'modified' : 'ok' }
}
