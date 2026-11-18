import { EditorContent, useEditor, type Editor, type JSONContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import { useState, type FormEvent } from 'react'

/** ProseMirror document, as the server stores and renders it (models/blocks/RichText.cfc) */
export type RichTextDoc = { type: 'doc'; content?: unknown[] }

const EMPTY: RichTextDoc = { type: 'doc', content: [] }

/**
 * TipTap with the nodes and marks the server allows: paragraphs, headings 2-4, lists, quotes, rules, line breaks,
 * bold, italic, underline, strike, code and links
 */
export function RichTextField({
  value,
  onChange,
  readOnly,
}: {
  value: unknown
  onChange: (value: RichTextDoc) => void
  readOnly?: boolean
}) {
  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        codeBlock: false,
        heading: { levels: [2, 3, 4] },
        link: { openOnClick: false, autolink: true },
      }),
    ],
    content: (isDoc(value) ? value : EMPTY) as JSONContent,
    editable: !readOnly,
    onUpdate: ({ editor: current }) => onChange(current.getJSON() as RichTextDoc),
  })

  if (!editor) return null
  return (
    <div className="studio-richtext">
      {!readOnly && <Toolbar editor={editor} />}
      <EditorContent editor={editor} className="studio-richtext__content" />
    </div>
  )
}

function isDoc(value: unknown): value is RichTextDoc {
  return typeof value === 'object' && value !== null && (value as { type?: unknown }).type === 'doc'
}

function Toolbar({ editor }: { editor: Editor }) {
  const [linking, setLinking] = useState(false)
  const [href, setHref] = useState('')
  const chain = () => editor.chain().focus()
  const button = (label: string, title: string, active: boolean, run: () => void) => (
    <button type="button" title={title} aria-label={title} aria-pressed={active} className={active ? 'is-active' : ''} onClick={run}>
      {label}
    </button>
  )

  function applyLink(event: FormEvent) {
    event.preventDefault()
    if (href.trim()) chain().extendMarkRange('link').setLink({ href: href.trim() }).run()
    else chain().extendMarkRange('link').unsetLink().run()
    setLinking(false)
  }

  return (
    <div className="studio-richtext__toolbar" role="toolbar" aria-label="Text formatting">
      {button('B', 'Bold', editor.isActive('bold'), () => chain().toggleBold().run())}
      {button('I', 'Italic', editor.isActive('italic'), () => chain().toggleItalic().run())}
      {button('U', 'Underline', editor.isActive('underline'), () => chain().toggleUnderline().run())}
      {button('S', 'Strikethrough', editor.isActive('strike'), () => chain().toggleStrike().run())}
      {button('H2', 'Heading 2', editor.isActive('heading', { level: 2 }), () => chain().toggleHeading({ level: 2 }).run())}
      {button('H3', 'Heading 3', editor.isActive('heading', { level: 3 }), () => chain().toggleHeading({ level: 3 }).run())}
      {button('•', 'Bullet list', editor.isActive('bulletList'), () => chain().toggleBulletList().run())}
      {button('1.', 'Numbered list', editor.isActive('orderedList'), () => chain().toggleOrderedList().run())}
      {button('“', 'Quote', editor.isActive('blockquote'), () => chain().toggleBlockquote().run())}
      {button('—', 'Horizontal line', false, () => chain().setHorizontalRule().run())}
      {button('🔗', 'Link', editor.isActive('link'), () => {
        setHref((editor.getAttributes('link').href as string | undefined) ?? '')
        setLinking(!linking)
      })}
      {linking && (
        <form onSubmit={applyLink} className="studio-richtext__link">
          <input
            autoFocus
            value={href}
            onChange={(event) => setHref(event.target.value)}
            placeholder="https://… or page:[slug] (empty removes the link)"
            aria-label="Link address"
          />
          <button type="submit">OK</button>
        </form>
      )}
    </div>
  )
}
