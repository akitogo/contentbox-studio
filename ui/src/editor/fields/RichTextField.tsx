import { EditorContent, useEditor, type Editor, type JSONContent } from '@tiptap/react'
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
  type LucideIcon,
} from 'lucide-react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Button, IconButton, Input } from '../../ui'
import { EMPTY_DOC, isDoc, richTextExtensions, type RichTextDoc } from '../richText'

export type { RichTextDoc } from '../richText'

/** The rich text field in the panel (TipTap); the same text can also be edited in the canvas (BlockPreview) */
export function RichTextField({
  value,
  onChange,
  readOnly,
}: {
  value: unknown
  onChange: (value: RichTextDoc) => void
  readOnly?: boolean
}) {
  // The value this editor shows, to tell changes made elsewhere (the canvas) from its own
  const shown = useRef(JSON.stringify(value))
  const editor = useEditor({
    extensions: richTextExtensions(),
    content: (isDoc(value) ? value : EMPTY_DOC) as JSONContent,
    editable: !readOnly,
    editorProps: { attributes: { class: 'studio-prose' } },
    onUpdate: ({ editor: current }) => {
      const doc = current.getJSON() as RichTextDoc
      shown.current = JSON.stringify(doc)
      onChange(doc)
    },
  })

  useEffect(() => {
    const json = JSON.stringify(value)
    if (!editor || json === shown.current || !isDoc(value)) return
    shown.current = json
    editor.commands.setContent(value as JSONContent, { emitUpdate: false })
  }, [editor, value])

  if (!editor) return null
  return (
    <div className="overflow-hidden rounded-md border border-slate-300 bg-white shadow-xs focus-within:border-primary-500 focus-within:ring-2 focus-within:ring-primary-500/20">
      {!readOnly && <Toolbar editor={editor} />}
      <EditorContent editor={editor} />
    </div>
  )
}

export interface FormattingTool {
  label: string
  Icon: LucideIcon
  active: boolean
  run: () => void
}

/** Formatting buttons of the panel and the canvas toolbar (the link has its own form) */
export function formattingTools(editor: Editor): FormattingTool[] {
  const chain = () => editor.chain().focus()
  return [
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
}

/** Sets the link of the selection (or the link the cursor is in); an empty address removes it */
export function applyLink(editor: Editor, href: string) {
  const chain = editor.chain().focus().extendMarkRange('link')
  if (href.trim()) chain.setLink({ href: href.trim() }).run()
  else chain.unsetLink().run()
}

export const LINK_PLACEHOLDER = 'https://… or page:[slug], empty removes the link'

function Toolbar({ editor }: { editor: Editor }) {
  const [linking, setLinking] = useState(false)
  const [href, setHref] = useState('')

  function submitLink(event: FormEvent) {
    event.preventDefault()
    applyLink(editor, href)
    setLinking(false)
  }

  const tools = formattingTools(editor)

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
        <form onSubmit={submitLink} className="mt-1 flex gap-1">
          <Input
            autoFocus
            className="h-7 text-xs"
            value={href}
            onChange={(event) => setHref(event.target.value)}
            placeholder={LINK_PLACEHOLDER}
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
