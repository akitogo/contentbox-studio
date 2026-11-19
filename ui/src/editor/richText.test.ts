import { getSchema } from '@tiptap/react'
import { describe, expect, it } from 'vitest'
import { editableDoc, positionAt, richTextExtensions } from './richText'

const schema = getSchema(richTextExtensions())
const paragraph = (...content: unknown[]) => ({ type: 'paragraph', content })
const text = (value: string, marks?: unknown[]) => (marks ? { type: 'text', text: value, marks } : { type: 'text', text: value })

describe('positionAt', () => {
  // <p>Hello</p><p>Wo<br>rld</p>: "Hello" at 1-6, the second paragraph's text from 8
  const doc = schema.nodeFromJSON({
    type: 'doc',
    content: [paragraph(text('Hello')), paragraph(text('Wo'), { type: 'hardBreak' }, text('rld'))],
  })

  it('finds the position after a number of characters, across paragraphs and line breaks', () => {
    expect(positionAt(doc, 0)).toBe(1)
    expect(positionAt(doc, 3)).toBe(4)
    // The end of a paragraph before the start of the next
    expect(positionAt(doc, 5)).toBe(6)
    expect(positionAt(doc, 6)).toBe(9)
    // After the line break (one position, no text)
    expect(positionAt(doc, 8)).toBe(12)
    expect(positionAt(doc, 10)).toBe(14)
  })

  it('gives null past the text', () => {
    expect(positionAt(doc, 11)).toBeNull()
    expect(positionAt(schema.nodeFromJSON({ type: 'doc', content: [paragraph()] }), 0)).toBeNull()
  })
})

describe('editableDoc', () => {
  const extensions = richTextExtensions()

  it('takes documents the editor can show unchanged', () => {
    const doc = { type: 'doc', content: [{ type: 'heading', attrs: { level: 2 }, content: [text('Title')] }, paragraph(text('Bold', [{ type: 'bold' }]))] }
    expect(editableDoc(doc, extensions)).toBe(doc)
  })

  it('refuses unknown formatting (TipTap would show the text empty) and anything not a document', () => {
    expect(editableDoc({ type: 'doc', content: [paragraph(text('H', [{ type: 'subscript' }]))] }, extensions)).toBeNull()
    expect(editableDoc({ type: 'doc', content: [{ type: 'table' }] }, extensions)).toBeNull()
    expect(editableDoc('<p>Hi</p>', extensions)).toBeNull()
    expect(editableDoc(undefined, extensions)).toBeNull()
  })
})

describe('richTextExtensions', () => {
  it('keeps links without a target (TipTap would give them _blank)', () => {
    const doc = schema.nodeFromJSON({
      type: 'doc',
      content: [paragraph(text('Here', [{ type: 'link', attrs: { href: '/contact' } }]), text(' and '), text('there', [{ type: 'link', attrs: { href: 'https://example.org', target: '_blank' } }]))],
    })
    const links = (doc.toJSON().content[0].content as { marks?: { attrs: { target: unknown } }[] }[])
      .filter((node) => node.marks)
      .map((node) => node.marks?.[0]?.attrs.target)
    expect(links).toEqual([null, '_blank'])
  })
})
