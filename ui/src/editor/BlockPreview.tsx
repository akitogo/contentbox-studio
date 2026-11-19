import { registerOverlayPortal, useGetPuck } from '@puckeditor/core'
import { Editor } from '@tiptap/react'
import { useEffect, useRef, useState, type CSSProperties, type FocusEvent, type FormEvent, type KeyboardEvent, type MouseEvent } from 'react'
import { messageOf, useStudio } from '../studio'
import type { BlockError } from '../types'
import { getPath, setPath } from './blocksData'
import { CanvasToolbar } from './CanvasToolbar'
import { useEditorContext } from './EditorContext'
import { editableDoc, offsetAtPoint, positionAt, richTextExtensions, tagClasses } from './richText'

interface RenderResult {
  blocks: { html: string }[]
  errors: BlockError[]
}

/** Rendered HTML by site, type and data, shared by all previews */
const cache = new Map<string, RenderResult>()

// Inline styles: the canvas only loads the theme's CSS, not Studio's
const PLACEHOLDER: CSSProperties = {
  padding: '14px 16px',
  border: '1px dashed #cbd5e1',
  borderRadius: 6,
  color: '#64748b',
  background: '#f8fafc',
  font: '13px/1.4 system-ui, -apple-system, sans-serif',
}
// Widget calls ({{{Name ...}}}) are expanded by ContentBox when the page is shown, not in the editor
const WIDGET = /\{\{\{(~?)([A-Za-z][A-Za-z0-9]*)([^}]*)\}\}\}/g
const PLACEHOLDER_INLINE =
  'padding:10px 14px;border:1px dashed #cbd5e1;border-radius:6px;color:#64748b;background:#f8fafc;font:13px/1.4 system-ui,-apple-system,sans-serif'

/** Server-rendered block HTML with placeholders for widget calls */
export function withWidgetPlaceholders(html: string): string {
  return html.replace(WIDGET, (_call, _nocache: string, name: string, args: string) => {
    const slug = name === 'ContentStore' ? /slug="([A-Za-z0-9_/-]+)"/.exec(args)?.[1] : undefined
    const label = slug ? `Content store item “${slug}”, shown on the page` : `Widget “${name}”, shown on the page`
    return `<div style="${PLACEHOLDER_INLINE}">${label}</div>`
  })
}

/** The value of a field edited in place: its text, single-line fields without line breaks */
export function editedValue(text: string, multiline: boolean): string {
  const value = text.replace(/\r/g, '').replace(/\n$/, '')
  return multiline ? value : value.replace(/\s*\n\s*/g, ' ')
}

const NOTE: CSSProperties = {
  margin: '4px 0 0',
  color: '#b45309',
  font: '12px/1.4 system-ui, -apple-system, sans-serif',
}

const fieldOf = (target: EventTarget | null) => (target as HTMLElement | null)?.closest?.<HTMLElement>('[data-cbs-field]') ?? null
const isRichText = (field: HTMLElement) => field.dataset.cbsType === 'richtext'

/** Rich text being edited in the canvas */
interface RichTextSession {
  editor: Editor
  /** The marked element (data-cbs-field) the editor is in */
  element: HTMLElement
  /** The server's HTML of the text, shown again if nothing changed */
  original: Node[]
  /** The document when editing started, as the editor gives it */
  initial: string
  onKeyDown: (event: globalThis.KeyboardEvent) => void
}

/**
 * A block in the editor canvas, rendered by the server with the theme's template (what will be saved).
 * Text the template shows unchanged from a text or rich text field is marked by the server (data-cbs-field) and can
 * be edited in place: text as plain content-editable text, rich text with TipTap and a formatting toolbar.
 * Everything else is edited in the fields on the right.
 */
export function BlockPreview({ type, label, id, data }: { type: string; label: string; id: string; data: Record<string, unknown> }) {
  const { config, api } = useStudio()
  const { siteID, canEdit } = useEditorContext()
  const getPuck = useGetPuck()
  const key = JSON.stringify([siteID, type, data])
  const [result, setResult] = useState<RenderResult | undefined>(cache.get(key))
  const [error, setError] = useState('')
  const [refresh, setRefresh] = useState(0)
  const editing = useRef(false)
  const container = useRef<HTMLDivElement>(null)
  const toolbar = useRef<HTMLDivElement>(null)
  // The session in a ref for event handlers (set at once), in state for rendering the toolbar
  const richText = useRef<RichTextSession | null>(null)
  const [richTextShown, setRichTextShown] = useState<RichTextSession | null>(null)

  useEffect(() => {
    // While text is edited in place the HTML stays (a new rendering would move the cursor); it is rendered on blur
    if (editing.current) return
    const cached = cache.get(key)
    if (cached) {
      setResult(cached)
      return
    }
    let cancelled = false
    const timer = window.setTimeout(() => {
      api
        .post<RenderResult>(`${config.studioApi}/blocks/render`, { site: siteID, blocks: [{ type, id, data }], editable: true })
        .then((rendered) => {
          cache.set(key, rendered)
          if (!cancelled) {
            setResult(rendered)
            setError('')
          }
        })
        .catch((e: unknown) => !cancelled && setError(messageOf(e)))
    }, 300)
    return () => {
      cancelled = true
      window.clearTimeout(timer)
    }
    // key covers site, type and data; the id does not change the HTML
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, refresh])

  const html = withWidgetPlaceholders(result?.blocks[0]?.html ?? '')

  // Marked text becomes editable; overlay portals take clicks through Puck's selection overlay
  useEffect(() => {
    const root = container.current
    if (!root || !canEdit) return
    const cleanups = [...root.querySelectorAll<HTMLElement>('[data-cbs-field]')].map((element) => {
      if (isRichText(element)) {
        // TipTap takes over on click
        element.style.cursor = 'text'
      } else {
        element.contentEditable = 'plaintext-only'
        element.spellcheck = true
      }
      return registerOverlayPortal(element, { disableDragOnFocus: true })
    })
    return () => cleanups.forEach((cleanup) => cleanup?.())
  }, [html, canEdit])

  // A block removed (or the page left) while its rich text is edited
  useEffect(() => () => richText.current?.editor.destroy(), [])

  /** Select the block, so its fields show on the right */
  function select() {
    const puck = getPuck()
    const selector = puck.getSelectorForId(id)
    if (selector && puck.selectedItem?.props.id !== id) puck.dispatch({ type: 'setUi', ui: { itemSelector: selector } })
  }

  function onFocus(event: FocusEvent) {
    if (!fieldOf(event.target)) return
    editing.current = true
    // After Puck has handled the click
    window.setTimeout(select)
  }

  /** Puts a field's new value into Puck's data (the fields on the right follow) */
  function replaceField(path: string, value: unknown) {
    const puck = getPuck()
    const selector = puck.getSelectorForId(id)
    const item = puck.getItemById(id)
    if (!selector || !item) return
    puck.dispatch({
      type: 'replace',
      destinationIndex: selector.index,
      destinationZone: selector.zone,
      data: { ...item, props: { ...setPath(item.props, path, value), id: item.props.id } },
    })
  }

  /** TipTap in place of the server's HTML of a rich text field, the cursor where it was clicked */
  function startRichText(element: HTMLElement, x: number, y: number) {
    const path = element.dataset.cbsField
    const item = getPuck().getItemById(id)
    if (!path || !item) return
    const extensions = richTextExtensions(tagClasses(element))
    // Formatting the editor does not know (subscript, ...) would get lost: such text is not editable here
    const content = editableDoc(getPath(item.props, path), extensions)
    if (!content) return
    const offset = offsetAtPoint(element, x, y)
    const original = [...element.childNodes]
    element.replaceChildren()
    editing.current = true
    const editor = new Editor({
      element,
      extensions,
      content,
      injectCSS: false,
      // The canvas has no TipTap CSS; ProseMirror needs whitespace kept
      editorProps: { attributes: { style: 'white-space: pre-wrap; word-wrap: break-word' } },
      onUpdate: ({ editor: current }) => replaceField(path, current.getJSON()),
    })
    const onKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        editor.view.dom.blur()
      }
      // Puck's shortcuts are for the page, not the text: Cmd+Z is the text's undo, Cmd+I italic, Backspace no delete
      event.stopPropagation()
    }
    element.addEventListener('keydown', onKeyDown)
    const session = { editor, element, original, initial: JSON.stringify(editor.getJSON()), onKeyDown }
    richText.current = session
    setRichTextShown(session)
    const position = offset === null ? null : positionAt(editor.state.doc, offset)
    editor.commands.focus(position ?? 'end')
  }

  /** Back to HTML: the edited text until the server's rendering arrives, the server's HTML if nothing changed */
  function stopRichText() {
    const session = richText.current
    if (!session) return
    richText.current = null
    setRichTextShown(null)
    const { editor, element, original, initial, onKeyDown } = session
    element.removeEventListener('keydown', onKeyDown)
    const changed = JSON.stringify(editor.getJSON()) !== initial
    const shown = changed ? [...editor.view.dom.cloneNode(true).childNodes] : original
    editor.destroy()
    element.replaceChildren(...shown)
    editing.current = false
    setRefresh((count) => count + 1)
  }

  // A click into editable text is not a click on the block for Puck (a second click would deselect it)
  function onClick(event: MouseEvent) {
    const field = fieldOf(event.target)
    if (!field) return
    event.stopPropagation()
    if (!isRichText(field)) return
    // Links in the text are not followed
    event.preventDefault()
    if (canEdit && !richText.current) startRichText(field, event.clientX, event.clientY)
  }

  function onInput(event: FormEvent) {
    const field = fieldOf(event.target)
    const path = field?.dataset.cbsField
    // Rich text reports its changes itself (TipTap's onUpdate)
    if (!field || !path || isRichText(field)) return
    replaceField(path, editedValue(field.innerText, field.dataset.cbsType === 'textarea'))
  }

  function onBlur(event: FocusEvent) {
    const session = richText.current
    if (session) {
      // The toolbar's link field is part of editing; the toolbar is in the React tree, so its events come here too
      // Canvas nodes are not instances of this window's Node (an iframe), so no instanceof
      const within = (target: EventTarget | null) => {
        const node = target as Node | null
        return !!node && (session.element.contains(node) || !!toolbar.current?.contains(node))
      }
      if (within(event.target) && !within(event.relatedTarget)) stopRichText()
      return
    }
    if (!fieldOf(event.target)) return
    editing.current = false
    setRefresh((count) => count + 1)
  }

  function onKeyDown(event: KeyboardEvent) {
    const field = fieldOf(event.target)
    if (!field || isRichText(field)) return
    if (event.key === 'Escape' || (event.key === 'Enter' && field.dataset.cbsType !== 'textarea')) {
      event.preventDefault()
      field.blur()
    }
  }

  const missing = result?.errors.map((item) => item.message).join(' ')

  return (
    // Handlers here, not on the HTML's div: they also get the events of the toolbar (a portal into the canvas body)
    <div data-block-type={type} style={{ minHeight: 24 }} onFocus={onFocus} onBlur={onBlur}>
      {html ? (
        <div ref={container} onClick={onClick} onInput={onInput} onKeyDown={onKeyDown} dangerouslySetInnerHTML={{ __html: html }} />
      ) : (
        <div style={PLACEHOLDER}>{result ? `${label}: fill in the fields on the right` : 'Rendering…'}</div>
      )}
      {(missing || error) && <p style={NOTE}>{error || missing}</p>}
      {richTextShown && <CanvasToolbar editor={richTextShown.editor} anchor={richTextShown.element} toolbar={toolbar} />}
    </div>
  )
}
