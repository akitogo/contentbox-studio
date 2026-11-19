import { describe, expect, it } from 'vitest'
import type { ParsedBlock } from '../blocks/format'
import type { BlockDefinition } from '../types'
import { fromPuckData, isFieldVisible, itemSummary, setPath, toPuckData, typesByName, withDefaults } from './blocksData'

const heading: BlockDefinition = {
  name: 'heading',
  label: 'Heading',
  description: '',
  icon: 'heading',
  category: 'text',
  version: 1,
  source: 'core',
  fields: [
    { name: 'text', type: 'text', label: 'Text', help: '', required: true, default: '' },
    { name: 'level', type: 'select', label: 'Level', help: '', required: false, default: '2', options: [{ value: '2', label: 'H2' }] },
  ],
}
const types = typesByName([heading])

const block = (overrides: Partial<ParsedBlock>): ParsedBlock => ({
  type: 'heading',
  v: 1,
  id: 'h1',
  data: { text: 'Hi' },
  html: '<h2>Hi</h2>',
  status: 'ok',
  ...overrides,
})

describe('toPuckData', () => {
  it('turns blocks into Puck items with defaults for missing fields', () => {
    const { data, notices } = toPuckData([block({})], types)
    expect(data.content).toEqual([{ type: 'heading', props: { id: 'h1', text: 'Hi', level: '2' } }])
    expect(notices).toEqual([])
  })

  it('loads legacy, invalid and unknown blocks as HTML and reports them', () => {
    const { data, notices } = toPuckData(
      [
        block({ type: 'html', id: 'legacy-1', status: 'legacy', html: '<p>old</p>', data: { html: '<p>old</p>' } }),
        block({ type: 'gone', id: 'g1', html: '<div>gone</div>' }),
        block({ id: 'm1', status: 'modified', html: '<h2>edited</h2>' }),
      ],
      types,
    )
    expect(data.content.map((item) => item.type)).toEqual(['html', 'html', 'heading'])
    expect(data.content[1]?.props).toEqual({ id: 'g1', html: '<div>gone</div>' })
    expect(notices.map((notice) => notice.status)).toEqual(['legacy', 'modified'])
  })
})

describe('fromPuckData', () => {
  it('turns Puck items back into blocks for the API', () => {
    expect(fromPuckData({ root: { props: {} }, content: [{ type: 'heading', props: { id: 'h1', text: 'Hi', level: '3' } }] })).toEqual([
      { type: 'heading', id: 'h1', data: { text: 'Hi', level: '3' } },
    ])
  })
})

describe('helpers', () => {
  it('copies defaults so items do not share them', () => {
    const fields = [{ name: 'items', type: 'list' as const, label: 'Items', help: '', required: false, default: [] }]
    const a = withDefaults(fields)
    const b = withDefaults(fields)
    expect(a.items).toEqual([])
    expect(a.items).not.toBe(b.items)
  })

  it('summarizes list items by their first text', () => {
    expect(itemSummary(heading.fields, { text: 'Rooms' }, 0)).toBe('Rooms')
    expect(itemSummary(heading.fields, {}, 2)).toBe('Item 3')
  })
})

describe('isFieldVisible', () => {
  const field = (when?: Record<string, string[]>) => ({ name: 'x', type: 'text' as const, label: 'X', help: '', required: false, default: '', when })

  it('shows fields without conditions', () => {
    expect(isFieldVisible(field(), {})).toBe(true)
  })

  it('shows a field when every named field has one of the values', () => {
    const name = field({ kind: ['card', 'box'], boxed: ['true'] })
    expect(isFieldVisible(name, { kind: 'card', boxed: true })).toBe(true)
    expect(isFieldVisible(name, { kind: 'none', boxed: true })).toBe(false)
    expect(isFieldVisible(name, { kind: 'box', boxed: false })).toBe(false)
    expect(isFieldVisible(name, {})).toBe(false)
  })
})

describe('setPath', () => {
  it('changes one value by path and copies every level on the way', () => {
    const props = { id: 'b1', title: 'Old', steps: [{ title: 'A' }, { title: 'B' }] }
    const next = setPath(props, 'steps.1.title', 'New')
    expect(next).toEqual({ id: 'b1', title: 'Old', steps: [{ title: 'A' }, { title: 'New' }] })
    expect(next.steps).not.toBe(props.steps)
    expect((next.steps as unknown[])[0]).toBe(props.steps[0])
    expect(props.steps[1]?.title).toBe('B')
    expect(setPath(props, 'title', 'T').title).toBe('T')
  })
})
