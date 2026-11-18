/**
 * Conversion between Studio blocks and Puck's data, and the Puck fields for block type fields.
 * Pure functions (no React), so they are unit-tested; the custom field components are plugged in by puckConfig.tsx.
 */
import type { BlockStatus, ParsedBlock } from '../blocks/format'
import type { BlockDefinition, FieldDefinition } from '../types'

/** A block as the API takes it */
export interface BlockInput {
  type: string
  id: string
  data: Record<string, unknown>
}

/** Puck's content item; props.id is the block id */
export interface PuckItem {
  type: string
  props: Record<string, unknown> & { id: string }
}

export interface PuckData {
  root: { props: Record<string, unknown> }
  content: PuckItem[]
}

/** Status the editor shows for blocks that did not load as written by Studio */
export interface BlockNotice {
  id: string
  status: Exclude<BlockStatus, 'ok'>
  type: string
}

/**
 * Parsed blocks to Puck data. Legacy and invalid parts, and blocks of types the site no longer has, become HTML
 * blocks with their stored HTML. Blocks changed outside Studio keep their type and data (saving renders them anew).
 */
export function toPuckData(blocks: ParsedBlock[], types: Record<string, BlockDefinition>): { data: PuckData; notices: BlockNotice[] } {
  const notices: BlockNotice[] = []
  const content = blocks.map((block): PuckItem => {
    if (block.status !== 'ok') {
      notices.push({ id: block.id, status: block.status, type: block.type })
    }
    const known = block.type !== 'html' && block.status !== 'legacy' && block.status !== 'invalid' && types[block.type]
    if (!known) {
      return { type: 'html', props: { id: block.id, html: block.html } }
    }
    return { type: block.type, props: { ...withDefaults(types[block.type]?.fields ?? [], block.data), id: block.id } }
  })
  return { data: { root: { props: {} }, content }, notices }
}

export function fromPuckData(data: PuckData): BlockInput[] {
  return data.content.map((item) => {
    const { id, ...fields } = item.props
    return { type: item.type, id, data: fields }
  })
}

/** Field values with the defaults of missing fields */
export function withDefaults(fields: FieldDefinition[], data: Record<string, unknown> = {}): Record<string, unknown> {
  const result: Record<string, unknown> = {}
  for (const field of fields) {
    result[field.name] = field.name in data ? data[field.name] : structuredClone(field.default)
  }
  return result
}

/** Block types by name */
export function typesByName(definitions: BlockDefinition[]): Record<string, BlockDefinition> {
  return Object.fromEntries(definitions.map((definition) => [definition.name, definition]))
}

export function fieldLabel(field: FieldDefinition): string {
  return field.required ? `${field.label} *` : field.label
}

/** A short text for list items in the editor: the first text field with a value */
export function itemSummary(fields: FieldDefinition[], item: Record<string, unknown>, index: number): string {
  for (const field of fields) {
    const value = item[field.name]
    if ((field.type === 'text' || field.type === 'textarea') && typeof value === 'string' && value.trim()) {
      return value.length > 40 ? `${value.slice(0, 40)}…` : value
    }
  }
  return `Item ${index + 1}`
}
