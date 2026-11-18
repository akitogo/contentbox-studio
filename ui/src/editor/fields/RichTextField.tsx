import { EditorContent, useEditor, type Editor, type JSONContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import {
  Bold,
  Heading2,
  Heading3,
  Italic,
  Link as LinkIcon,
  List,
  ListOrdered,
  Minus,
  Quote,
  Strikethrough,
  Underline,
} from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { Button, IconButton, Input } from '../../ui'

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
    editorProps: { attributes: { class: 'studio-prose' } },
    onUpdate: ({ editor: current }) => onChange(current.getJSON() as RichTextDoc),
  })

  if (!editor) return null
  return (
    <div className="overflow-hidden rounded-md border border-slate-300 bg-white shadow-xs focus-within:border-primary-500 focus-within:ring-2 focus-within:ring-primary-500/20">
      {!readOnly && <Toolbar editor={editor} />}
      <EditorContent editor={editor} />
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

  function applyLink(event: FormEvent) {
    event.preventDefault()
    if (href.trim()) chain().extendMarkRange('link').setLink({ href: href.trim() }).run()
    else chain().extendMarkRange('link').unsetLink().run()
    setLinking(false)
  }

  const tools = [
    { label: 'Bold', Icon: Bold, active: editor.isActive('bold'), run: () => chain().toggleBold().run() },
    { label: 'Italic', Icon: Italic, active: editor.isActive('italic'), run: () => chain().toggleItalic().run() },
    { label: 'Underline', Icon: Underline, active: editor.isActive('underline'), run: () => chain().toggleUnderline().run() },
    { label: 'Strikethrough', Icon: Strikethrough, active: editor.isActive('strike'), run: () => chain().toggleStrike().run() },
    { label: 'Heading 2', Icon: Heading2, active: editor.isActive('heading', { level: 2 }), run: () => chain().toggleHeading({ level: 2 }).run() },
    { label: 'Heading 3', Icon: Heading3, active: editor.isActive('heading', { level: 3 }), run: () => chain().toggleHeading({ level: 3 }).run() },
    { label: 'Bullet list', Icon: List, active: editor.isActive('bulletList'), run: () => chain().toggleBulletList().run() },
    { label: 'Numbered list', Icon: ListOrdered, active: editor.isActive('orderedList'), run: () => chain().toggleOrderedList().run() },
    { label: 'Quote', Icon: Quote, active: editor.isActive('blockquote'), run: () => chain().toggleBlockquote().run() },
    { label: 'Horizontal line', Icon: Minus, active: false, run: () => chain().setHorizontalRule().run() },
  ]

  return (
    <div className="border-b border-slate-200 bg-slate-50 p-1">
      <div className="flex flex-wrap gap-0.5" role="toolbar" aria-label="Text formatting">
        {tools.map(({ label, Icon, active, run }) => (
          <IconButton key={label} label={label} active={active} aria-pressed={active} onClick={run}>
            <Icon className="size-3.5" />
          </IconButton>
        ))}
        <IconButton
          label="Link"
          active={editor.isActive('link')}
          aria-pressed={editor.isActive('link')}
          onClick={() => {
            setHref((editor.getAttributes('link').href as string | undefined) ?? '')
            setLinking(!linking)
          }}
        >
          <LinkIcon className="size-3.5" />
        </IconButton>
      </div>
      {linking && (
        <form onSubmit={applyLink} className="mt-1 flex gap-1">
          <Input
            autoFocus
            className="h-7 text-xs"
            value={href}
            onChange={(event) => setHref(event.target.value)}
            placeholder="https://… or page:[slug], empty removes the link"
            aria-label="Link address"
          />
          <Button type="submit" size="sm">
            Apply
          </Button>
        </form>
      )}
    </div>
  )
}
