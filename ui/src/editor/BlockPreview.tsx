import { useEffect, useState } from 'react'
import { messageOf, useStudio } from '../studio'
import type { BlockError } from '../types'
import { useEditorContext } from './EditorContext'

interface RenderResult {
  blocks: { html: string }[]
  errors: BlockError[]
}

/** Rendered HTML by site, type and data, shared by all previews */
const cache = new Map<string, RenderResult>()

/**
 * A block in the editor canvas, rendered by the server with the theme's template (what will be saved)
 */
export function BlockPreview({ type, id, data }: { type: string; id: string; data: Record<string, unknown> }) {
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

  const html = result?.blocks[0]?.html ?? ''
  const contentStore = /^\{\{\{ContentStore slug="([^"]+)"\}\}\}$/.exec(html)?.[1]
  const missing = result?.errors.map((item) => item.message).join(' ')

  return (
    <div className="studio-preview-block" data-block-type={type}>
      {contentStore ? (
        <div className="studio-preview-placeholder">Content store item “{contentStore}” (shown on the page)</div>
      ) : html ? (
        <div dangerouslySetInnerHTML={{ __html: html }} />
      ) : (
        <div className="studio-preview-placeholder">{result ? `Empty ${type} block` : 'Rendering…'}</div>
      )}
      {(missing || error) && <p className="studio-preview-note">{error || missing}</p>}
    </div>
  )
}
