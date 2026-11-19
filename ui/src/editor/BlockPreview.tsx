import { useEffect, useState, type CSSProperties } from 'react'
import { messageOf, useStudio } from '../studio'
import type { BlockError } from '../types'
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

const NOTE: CSSProperties = {
  margin: '4px 0 0',
  color: '#b45309',
  font: '12px/1.4 system-ui, -apple-system, sans-serif',
}

/**
 * A block in the editor canvas, rendered by the server with the theme's template (what will be saved)
 */
export function BlockPreview({ type, label, id, data }: { type: string; label: string; id: string; data: Record<string, unknown> }) {
  const { config, api } = useStudio()
  const { siteID } = useEditorContext()
  const key = JSON.stringify([siteID, type, data])
  const [result, setResult] = useState<RenderResult | undefined>(cache.get(key))
  const [error, setError] = useState('')

  useEffect(() => {
    const cached = cache.get(key)
    if (cached) {
      setResult(cached)
      return
    }
    let cancelled = false
    const timer = window.setTimeout(() => {
      api
        .post<RenderResult>(`${config.studioApi}/blocks/render`, { site: siteID, blocks: [{ type, id, data }] })
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
  }, [key])

  const html = withWidgetPlaceholders(result?.blocks[0]?.html ?? '')
  const missing = result?.errors.map((item) => item.message).join(' ')

  return (
    <div data-block-type={type} style={{ minHeight: 24 }}>
      {html ? (
        <div dangerouslySetInnerHTML={{ __html: html }} />
      ) : (
        <div style={PLACEHOLDER}>{result ? `${label}: fill in the fields on the right` : 'Rendering…'}</div>
      )}
      {(missing || error) && <p style={NOTE}>{error || missing}</p>}
    </div>
  )
}
