import type { Editor } from '@tiptap/react'
import { Check, Link as LinkIcon } from 'lucide-react'
import { useLayoutEffect, useReducer, useState, type CSSProperties, type FormEvent, type KeyboardEvent, type RefObject } from 'react'
import { createPortal } from 'react-dom'
import { applyLink, formattingTools, LINK_PLACEHOLDER } from './fields/RichTextField'

// The canvas only loads the theme's CSS, not Studio's: own styles, reset against the theme's button and input styles
const CSS = `
.cbs-toolbar{position:fixed;z-index:2147483647;display:flex;flex-wrap:wrap;align-items:center;gap:2px;box-sizing:border-box;transform-origin:top left;padding:4px;border:1px solid #cbd5e1;border-radius:8px;background:#fff;box-shadow:0 4px 14px rgba(15,23,42,.16);color:#334155;font:13px/1.2 system-ui,-apple-system,sans-serif;text-align:left}
.cbs-toolbar button{all:unset;box-sizing:border-box;display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;border-radius:6px;color:#334155;cursor:pointer}
.cbs-toolbar button:hover{background:#f1f5f9}
.cbs-toolbar button[aria-pressed=true]{background:#cfdff0;color:#014292}
.cbs-toolbar button:focus-visible{outline:2px solid #3479be;outline-offset:1px}
.cbs-toolbar svg{width:15px;height:15px;flex:none}
.cbs-toolbar .cbs-sep{width:1px;height:18px;margin:0 3px;background:#e2e8f0}
.cbs-toolbar form{display:flex;flex-basis:100%;gap:4px;margin:2px 0 0}
.cbs-toolbar input{all:unset;box-sizing:border-box;flex:1;min-width:240px;height:28px;padding:0 8px;border:1px solid #cbd5e1;border-radius:6px;background:#fff;color:#0f172a;font:inherit}
.cbs-toolbar input:focus{border-color:#3479be;box-shadow:0 0 0 2px rgba(52,121,190,.2)}
.cbs-toolbar form button{width:auto;padding:0 10px;background:#0158ad;color:#fff;font-weight:500}
.cbs-toolbar form button:hover{background:#014292}
`

/**
 * Formatting toolbar for rich text edited in the canvas, above the text (below it or at the top of the canvas when
 * there is no room). Rendered into the canvas document, at its normal size whatever the canvas zoom; clicks on it
 * keep the focus in the text.
 */
export function CanvasToolbar({ editor, anchor, toolbar }: { editor: Editor; anchor: HTMLElement; toolbar: RefObject<HTMLDivElement | null> }) {
  const [, rerender] = useReducer((count: number) => count + 1, 0)
  const [place, setPlace] = useState<CSSProperties>({ visibility: 'hidden' })
  const [linking, setLinking] = useState(false)
  const [href, setHref] = useState('')

  useLayoutEffect(() => {
    const view = anchor.ownerDocument.defaultView
    if (!view) return
    const position = () => {
      const element = toolbar.current
      if (!element) return
      // Puck zooms the canvas by scaling the iframe: the toolbar is scaled back, sizes below are in canvas pixels
      const frame = view.frameElement as HTMLElement | null
      const scale = frame?.offsetWidth ? frame.getBoundingClientRect().width / frame.offsetWidth : 1
      const [gap, edge] = [8 / scale, 4 / scale]
      const height = element.offsetHeight / scale
      const width = element.offsetWidth / scale
      const rect = anchor.getBoundingClientRect()
      let top = rect.top - height - gap
      if (top < edge) top = rect.bottom + gap + height <= view.innerHeight ? rect.bottom + gap : edge
      const left = Math.max(edge, Math.min(rect.left, view.innerWidth - width - edge))
      const visible = rect.bottom > 0 && rect.top < view.innerHeight
      setPlace({
        top,
        left,
        maxWidth: (view.innerWidth - 2 * edge) * scale,
        transform: scale === 1 ? undefined : `scale(${1 / scale})`,
        visibility: visible ? 'visible' : 'hidden',
      })
    }
    const onTransaction = () => {
      rerender()
      position()
    }
    position()
    view.addEventListener('scroll', position, true)
    view.addEventListener('resize', position)
    editor.on('transaction', onTransaction)
    return () => {
      view.removeEventListener('scroll', position, true)
      view.removeEventListener('resize', position)
      editor.off('transaction', onTransaction)
    }
  }, [anchor, editor, toolbar, linking])

  // Back to the text before the link field goes away (TipTap's focus() waits a frame; editing ends without focus)
  function closeLink() {
    editor.view.focus()
    setLinking(false)
  }

  function submitLink(event: FormEvent) {
    event.preventDefault()
    closeLink()
    applyLink(editor, href)
  }

  function onKeyDown(event: KeyboardEvent) {
    // Puck's shortcuts (undo, delete block, ...) are not for the toolbar
    event.stopPropagation()
    if (event.key === 'Escape') closeLink()
  }

  const tools = formattingTools(editor)
  const linkActive = editor.isActive('link')

  return createPortal(
    <div
      ref={toolbar}
      className="cbs-toolbar"
      style={place}
      role="toolbar"
      aria-label="Text formatting"
      // Not a click on the block for Puck; buttons keep the focus (and selection) in the text
      onPointerDown={(event) => event.stopPropagation()}
      onMouseDown={(event) => {
        event.stopPropagation()
        if (!(event.target as HTMLElement).closest('input')) event.preventDefault()
      }}
      onClick={(event) => event.stopPropagation()}
      onKeyDown={onKeyDown}
    >
      <style>{CSS}</style>
      {tools.map(({ label, Icon, active, run }) => (
        <button key={label} type="button" title={label} aria-label={label} aria-pressed={active} onClick={run}>
          <Icon aria-hidden />
        </button>
      ))}
      <button
        type="button"
        title="Link"
        aria-label="Link"
        aria-pressed={linkActive}
        onClick={() => {
          setHref((editor.getAttributes('link').href as string | undefined) ?? '')
          setLinking(!linking)
        }}
      >
        <LinkIcon aria-hidden />
      </button>
      <span className="cbs-sep" aria-hidden />
      <button type="button" title="Done (Esc)" aria-label="Done" onClick={() => editor.view.dom.blur()}>
        <Check aria-hidden />
      </button>
      {linking && (
        <form onSubmit={submitLink}>
          <input
            autoFocus
            value={href}
            onChange={(event) => setHref(event.target.value)}
            placeholder={LINK_PLACEHOLDER}
            aria-label="Link address"
          />
          <button type="submit">Apply</button>
        </form>
      )}
    </div>,
    anchor.ownerDocument.body,
  )
}
