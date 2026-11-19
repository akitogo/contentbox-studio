import { registerOverlayPortal, useGetPuck } from '@puckeditor/core'
import { useEffect, useRef, useState, type CSSProperties, type FocusEvent, type FormEvent, type KeyboardEvent, type MouseEvent } from 'react'
import { messageOf, useStudio } from '../studio'
import type { BlockError } from '../types'
import { setPath } from './blocksData'
import { useEditorContext } from './EditorContext'

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

/**
 * A block in the editor canvas, rendered by the server with the theme's template (what will be saved).
 * Text the template shows unchanged from a text field is marked by the server (data-cbs-field) and can be edited
 * in place; everything else is edited in the fields on the right.
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
      element.contentEditable = 'plaintext-only'
      element.spellcheck = true
      return registerOverlayPortal(element, { disableDragOnFocus: true })
    })
    return () => cleanups.forEach((cleanup) => cleanup?.())
  }, [html, canEdit])

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

  // A click into editable text is not a click on the block for Puck (a second click would deselect it)
  function onClick(event: MouseEvent) {
    if (fieldOf(event.target)) event.stopPropagation()
  }

  function onInput(event: FormEvent) {
    const field = fieldOf(event.target)
    const path = field?.dataset.cbsField
    if (!field || !path) return
    const puck = getPuck()
    const selector = puck.getSelectorForId(id)
    const item = puck.getItemById(id)
    if (!selector || !item) return
    puck.dispatch({
      type: 'replace',
      destinationIndex: selector.index,
      destinationZone: selector.zone,
      data: {
        ...item,
        props: { ...setPath(item.props, path, editedValue(field.innerText, field.dataset.cbsType === 'textarea')), id: item.props.id },
      },
    })
  }

  function onBlur(event: FocusEvent) {
    if (!fieldOf(event.target)) return
    editing.current = false
    setRefresh((count) => count + 1)
  }

  function onKeyDown(event: KeyboardEvent) {
    const field = fieldOf(event.target)
    if (!field) return
    if (event.key === 'Escape' || (event.key === 'Enter' && field.dataset.cbsType !== 'textarea')) {
      event.preventDefault()
      field.blur()
    }
  }

  const missing = result?.errors.map((item) => item.message).join(' ')

  return (
    <div data-block-type={type} style={{ minHeight: 24 }}>
      {html ? (
        <div
          ref={container}
          onClick={onClick}
          onFocus={onFocus}
          onInput={onInput}
          onBlur={onBlur}
          onKeyDown={onKeyDown}
          dangerouslySetInnerHTML={{ __html: html }}
        />
      ) : (
        <div style={PLACEHOLDER}>{result ? `${label}: fill in the fields on the right` : 'Rendering…'}</div>
      )}
      {(missing || error) && <p style={NOTE}>{error || missing}</p>}
    </div>
  )
}
