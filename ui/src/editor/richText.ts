/**
 * TipTap setup shared by the rich text field (panel) and rich text edited in place in the canvas, plus the helpers
 * the canvas needs: the theme's classes on the editor's elements, and the cursor where the text was clicked.
 */
import { Extension, getSchema, mergeAttributes, type AnyExtension, type JSONContent } from '@tiptap/react'
import Link from '@tiptap/extension-link'
import type { DOMOutputSpec, Node as ProseMirrorNode } from '@tiptap/pm/model'
import { Plugin } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'
import StarterKit from '@tiptap/starter-kit'

/** ProseMirror document, as the server stores and renders it (models/blocks/RichText.cfc) */
export type RichTextDoc = { type: 'doc'; content?: unknown[] }

export const EMPTY_DOC: RichTextDoc = { type: 'doc', content: [] }

export function isDoc(value: unknown): value is RichTextDoc {
  return typeof value === 'object' && value !== null && (value as { type?: unknown }).type === 'doc'
}

/** Classes by tag name (p, h2, a, strong, ...), as a theme's template puts them on rich text */
export type TagClasses = Record<string, string>

const MARK_TAGS = { bold: 'strong', italic: 'em', underline: 'u', strike: 's', code: 'code' } as const

/**
 * The nodes and marks the server allows: paragraphs, headings 2-4, lists, quotes, rules, line breaks, bold, italic,
 * underline, strike, code and links. With classes, the editor's elements get the classes the theme gives them, so
 * text edited in the canvas keeps its look.
 */
export function richTextExtensions(classes: TagClasses = {}): AnyExtension[] {
  const mark = (name: keyof typeof MARK_TAGS) => {
    const value = classes[MARK_TAGS[name]]
    return value ? { HTMLAttributes: { class: value } } : {}
  }
  return [
    StarterKit.configure({
      codeBlock: false,
      heading: { levels: [2, 3, 4] },
      link: false,
      bold: mark('bold'),
      italic: mark('italic'),
      underline: mark('underline'),
      strike: mark('strike'),
      code: mark('code'),
    }),
    Link.extend({
      renderHTML(props) {
        const [tag, attributes, hole] = this.parent?.(props) as [string, Record<string, unknown>, 0]
        return (classes.a ? [tag, mergeAttributes(attributes, { class: classes.a }), hole] : [tag, attributes, hole]) as DOMOutputSpec
      },
    }).configure({
      openOnClick: false,
      autolink: true,
      // No default target: TipTap's (_blank) would be given to every link of a text as soon as it is edited
      HTMLAttributes: { target: null, rel: null },
    }),
    ...(Object.keys(classes).length ? [nodeClasses(classes)] : []),
  ]
}

/** The document, if the editor knows all its nodes and marks (else TipTap would show it empty), or null */
export function editableDoc(value: unknown, extensions: AnyExtension[]): JSONContent | null {
  if (!isDoc(value)) return null
  try {
    getSchema(extensions).nodeFromJSON(value).check()
    return value as JSONContent
  } catch {
    return null
  }
}

function nodeTag(node: ProseMirrorNode): string | undefined {
  switch (node.type.name) {
    case 'paragraph':
      return 'p'
    case 'heading':
      return `h${node.attrs.level as number}`
    case 'bulletList':
      return 'ul'
    case 'orderedList':
      return 'ol'
    case 'listItem':
      return 'li'
    case 'blockquote':
      return 'blockquote'
    case 'horizontalRule':
      return 'hr'
  }
}

/** Classes on block elements as decorations: they never become part of the document */
function nodeClasses(classes: TagClasses) {
  return Extension.create({
    name: 'studioNodeClasses',
    addProseMirrorPlugins() {
      return [
        new Plugin({
          props: {
            decorations(state) {
              const decorations: Decoration[] = []
              state.doc.descendants((node, pos) => {
                const tag = nodeTag(node)
                const value = tag && classes[tag]
                if (value) decorations.push(Decoration.node(pos, pos + node.nodeSize, { class: value }))
              })
              return DecorationSet.create(state.doc, decorations)
            },
          },
        }),
      ]
    },
  })
}

/** The class of the first element of each tag in rendered rich text */
export function tagClasses(root: Element): TagClasses {
  const classes: TagClasses = {}
  for (const element of root.querySelectorAll('*')) {
    const tag = element.tagName.toLowerCase()
    const value = element.getAttribute('class')
    if (value && !(tag in classes)) classes[tag] = value
  }
  return classes
}

/** Characters of text in root before a DOM position (line breaks and tags count nothing, like in the document) */
export function textOffset(root: Node, node: Node, offset: number): number | null {
  if (!root.contains(node) || !root.ownerDocument) return null
  const range = root.ownerDocument.createRange()
  range.setStart(root, 0)
  range.setEnd(node, offset)
  return range.toString().length
}

/** Text offset in root at a point of the viewport (e.g. a click), or null */
export function offsetAtPoint(root: Element, x: number, y: number): number | null {
  const doc = root.ownerDocument as Document & { caretRangeFromPoint?: (x: number, y: number) => Range | null }
  if (typeof doc.caretPositionFromPoint === 'function') {
    const position = doc.caretPositionFromPoint(x, y)
    return position ? textOffset(root, position.offsetNode, position.offset) : null
  }
  const range = doc.caretRangeFromPoint?.(x, y)
  return range ? textOffset(root, range.startContainer, range.startOffset) : null
}

/** Document position after this many characters of text, or null if the document has less text */
export function positionAt(doc: ProseMirrorNode, offset: number): number | null {
  let remaining = offset
  let found: number | null = null
  doc.descendants((node, pos) => {
    if (found !== null) return false
    if (node.isText) {
      const length = node.text?.length ?? 0
      if (remaining <= length) {
        found = pos + remaining
        return false
      }
      remaining -= length
    }
    return true
  })
  return found
}
