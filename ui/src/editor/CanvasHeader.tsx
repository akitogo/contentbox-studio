/**
 * The header of a blog entry above its blocks in the editor canvas: title, date, author, categories and featured image,
 * rendered by the server with the theme's template (POST /content/:id/header) from the values being edited, so it
 * changes with the entry settings. The title is edited in place (plain text, one line) and saved with Save.
 */
import { useContext, useEffect, useRef, useState, type FocusEvent, type FormEvent, type KeyboardEvent } from 'react'
import { useStudio } from '../studio'
import { editedValue } from './BlockPreview'
import { EditorActionsContext } from './EditorActions'

export function CanvasHeader() {
  const actions = useContext(EditorActionsContext)
  const { config, api } = useStudio()
  const [html, setHtml] = useState('')
  const [refresh, setRefresh] = useState(0)
  const editing = useRef(false)
  const container = useRef<HTMLDivElement>(null)
  // The latest settings for the input handler (a render can be pending while typing)
  const latest = useRef(actions)
  latest.current = actions

  const settings = actions?.settings
  const entry = settings?.entry
  const contentID = actions?.content.contentID ?? ''
  const values = settings && entry
    ? {
        title: settings.title,
        publishedDate: entry.publishedDate,
        categories: entry.categories.map((category) => category.name),
        featuredImage: entry.featuredImageURL,
      }
    : null
  const key = JSON.stringify(values)

  useEffect(() => {
    // While the title is edited the HTML stays (a new rendering would move the cursor); it is rendered on blur
    if (!values || editing.current) return
    let cancelled = false
    const timer = window.setTimeout(() => {
      api
        .post<{ html: string }>(`${config.studioApi}/content/${encodeURIComponent(contentID)}/header`, values)
        .then((result) => !cancelled && setHtml(result.html))
        .catch(() => undefined)
    }, 250)
    return () => {
      cancelled = true
      window.clearTimeout(timer)
    }
    // key covers the values
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, refresh, contentID])

  // The title the template outputs unchanged is marked (data-cbs-field="title"): editable as plain text
  const canEdit = actions?.canEdit ?? false
  useEffect(() => {
    const field = container.current?.querySelector<HTMLElement>('[data-cbs-field="title"]')
    if (!field || !canEdit) return
    field.contentEditable = 'plaintext-only'
    field.spellcheck = true
  }, [html, canEdit])

  function onInput(event: FormEvent) {
    const field = (event.target as HTMLElement).closest?.<HTMLElement>('[data-cbs-field="title"]')
    const current = latest.current
    if (!field || !current?.settings) return
    current.setSettings({ ...current.settings, title: editedValue(field.innerText, false) })
  }

  function onFocus(event: FocusEvent) {
    if ((event.target as HTMLElement).closest?.('[data-cbs-field]')) editing.current = true
  }

  function onBlur(event: FocusEvent) {
    if (!(event.target as HTMLElement).closest?.('[data-cbs-field]')) return
    editing.current = false
    setRefresh((count) => count + 1)
  }

  function onKeyDown(event: KeyboardEvent) {
    if (!(event.target as HTMLElement).closest?.('[data-cbs-field]')) return
    // Puck's shortcuts are for the blocks, not the title
    event.stopPropagation()
    if (event.key === 'Enter' || event.key === 'Escape') {
      event.preventDefault()
      ;(event.target as HTMLElement).blur()
    }
  }

  if (!html) return null
  return (
    <div
      ref={container}
      data-cbs-canvas-header
      onInput={onInput}
      onFocus={onFocus}
      onBlur={onBlur}
      onKeyDown={onKeyDown}
      dangerouslySetInnerHTML={{ __html: html }}
    />
  )
}
