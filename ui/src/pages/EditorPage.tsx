import { Puck } from '@puckeditor/core'
import '@puckeditor/core/no-external.css'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useParams } from 'react-router'
import { ApiError } from '../api'
import type { ParsedBlock } from '../blocks/format'
import { Header } from '../components/Header'
import { fromPuckData, toPuckData, typesByName, type BlockNotice, type PuckData } from '../editor/blocksData'
import { EditorContext, type EditorContextValue } from '../editor/EditorContext'
import { openPreview, previewFields, previewUrl } from '../editor/preview'
import { buildConfig } from '../editor/puckConfig'
import { VersionsPanel } from '../editor/VersionsPanel'
import { messageOf, useStudio } from '../studio'
import type { BlockDefinition, BlockError, EditorContent, TreePage } from '../types'

const NOTICE_TEXT: Record<BlockNotice['status'], string> = {
  legacy: 'HTML written outside Studio, shown as an HTML block',
  invalid: 'a block Studio could not read, shown as an HTML block',
  modified: 'changed outside Studio; saving renders it again from its fields and drops those changes',
}

interface Loaded {
  editor: EditorContent
  definitions: BlockDefinition[]
  context: EditorContextValue
}

export function EditorPage() {
  const { contentID = '' } = useParams()
  const { config, api } = useStudio()
  const [loaded, setLoaded] = useState<Loaded | null>(null)
  const [initial, setInitial] = useState<{ data: PuckData; notices: BlockNotice[]; key: number } | null>(null)
  const [loadError, setLoadError] = useState('')
  const [message, setMessage] = useState<{ kind: 'error' | 'info'; text: string } | null>(null)
  const [errors, setErrors] = useState<BlockError[]>([])
  const [changelog, setChangelog] = useState('')
  const [saving, setSaving] = useState(false)
  const [dirty, setDirty] = useState(false)
  const [showVersions, setShowVersions] = useState(false)
  const current = useRef<PuckData | null>(null)

  const show = useCallback((blocks: ParsedBlock[], definitions: BlockDefinition[]) => {
    const converted = toPuckData(blocks, typesByName(definitions))
    current.current = converted.data
    setInitial((previous) => ({ ...converted, key: (previous?.key ?? 0) + 1 }))
    setDirty(false)
  }, [])

  useEffect(() => {
    let cancelled = false
    async function load() {
      try {
        const editor = await api.get<EditorContent>(`${config.studioApi}/content/${contentID}`)
        const site = encodeURIComponent(editor.content.siteID)
        const [definitions, pages, contentStoreItems] = await Promise.all([
          api.get<BlockDefinition[]>(`${config.studioApi}/blocks?site=${site}`),
          api.get<TreePage[]>(`${config.studioApi}/sites/${site}/tree`),
          api.get<{ slug: string; title: string }[]>(`${config.studioApi}/sites/${site}/contentstore`),
        ])
        if (cancelled) return
        setLoaded({
          editor,
          definitions,
          context: {
            siteID: editor.content.siteID,
            canEdit: editor.canEdit,
            canEditHtml: editor.canEditHtml,
            pages,
            contentStoreItems,
          },
        })
        show(editor.blocks, definitions)
      } catch (error) {
        if (!cancelled) setLoadError(messageOf(error))
      }
    }
    void load()
    return () => {
      cancelled = true
    }
  }, [api, config, contentID, show])

  // Warn before leaving with unsaved changes
  useEffect(() => {
    if (!dirty) return
    const warn = (event: BeforeUnloadEvent) => event.preventDefault()
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [dirty])

  const puckConfig = useMemo(
    () => (loaded ? buildConfig(loaded.definitions, loaded.editor.canEditHtml) : null),
    [loaded],
  )

  async function save() {
    if (!loaded || !current.current) return
    setSaving(true)
    setMessage(null)
    setErrors([])
    try {
      const result = await api.put<EditorContent>(`${config.studioApi}/content/${contentID}/blocks`, {
        blocks: fromPuckData(current.current),
        changelog,
        baseVersion: loaded.editor.content.version,
      })
      setLoaded({ ...loaded, editor: result })
      show(result.blocks, loaded.definitions)
      setChangelog('')
      setMessage({ kind: 'info', text: `Saved as version ${result.content.version}.` })
    } catch (error) {
      if (error instanceof ApiError && error.status === 422) {
        setErrors((error.data as { errors?: BlockError[] } | undefined)?.errors ?? [])
        setMessage({ kind: 'error', text: 'Not saved: some blocks need attention.' })
      } else {
        setMessage({ kind: 'error', text: `Not saved: ${messageOf(error)}` })
      }
    } finally {
      setSaving(false)
    }
  }

  async function preview() {
    if (!loaded || !current.current) return
    const url = previewUrl(config, loaded.editor.content)
    if (!url) return
    try {
      const rendered = await api.post<{ body: string }>(`${config.studioApi}/blocks/render`, {
        site: loaded.editor.content.siteID,
        blocks: fromPuckData(current.current),
      })
      openPreview(url, previewFields(config, loaded.editor.content, rendered.body))
    } catch (error) {
      setMessage({ kind: 'error', text: `Preview failed: ${messageOf(error)}` })
    }
  }

  if (loadError) {
    return (
      <div className="studio">
        <Header />
        <main className="studio-main">
          <p className="studio-error" role="alert">Could not open the content: {loadError}</p>
          <Link to="/">Back to the pages</Link>
        </main>
      </div>
    )
  }
  if (!loaded || !initial || !puckConfig) {
    return (
      <div className="studio">
        <Header />
        <p className="studio-muted studio-center">Loading…</p>
      </div>
    )
  }

  const { editor } = loaded
  const blockLabel = (id: string) => {
    const item = current.current?.content.find((block) => block.props.id === id)
    return item ? (loaded.definitions.find((definition) => definition.name === item.type)?.label ?? item.type) : id
  }

  return (
    <div className="studio studio--editor">
      <Header>
        <span className="studio-editor-title">
          <Link to={`/?site=${encodeURIComponent(editor.content.siteSlug)}`}>Pages</Link> / {editor.content.title}{' '}
          <small>
            version {editor.content.version}
            {dirty ? ' · unsaved changes' : ''}
          </small>
        </span>
      </Header>

      {(message || errors.length > 0 || initial.notices.length > 0 || !editor.canEdit) && (
        <div className="studio-editor-messages" role="status" aria-live="polite">
          {!editor.canEdit && <p className="studio-error">You can look at this content but not save it (missing permission).</p>}
          {message && <p className={message.kind === 'error' ? 'studio-error' : 'studio-muted'}>{message.text}</p>}
          {errors.length > 0 && (
            <ul className="studio-error">
              {errors.map((error, index) => (
                <li key={index}>
                  {blockLabel(error.blockID)}: {error.message}
                </li>
              ))}
            </ul>
          )}
          {initial.notices.length > 0 && (
            <ul className="studio-muted">
              {initial.notices.map((notice) => (
                <li key={notice.id}>
                  Block “{notice.type}” ({notice.id}): {NOTICE_TEXT[notice.status]}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <div className={`studio-editor${showVersions ? ' studio-editor--with-side' : ''}`}>
        <EditorContext.Provider value={loaded.context}>
          <Puck
            key={initial.key}
            config={puckConfig}
            data={initial.data}
            onChange={(data) => {
              current.current = data as PuckData
              setDirty(true)
            }}
            headerTitle={editor.content.title}
            headerPath={editor.content.url ? `/${editor.content.slug}` : editor.content.slug}
            permissions={{ edit: editor.canEdit, insert: editor.canEdit, delete: editor.canEdit, drag: editor.canEdit, duplicate: editor.canEdit }}
            overrides={{
              headerActions: () => (
                <div className="studio-editor-actions">
                  <input
                    value={changelog}
                    onChange={(event) => setChangelog(event.target.value)}
                    placeholder="What changed? (optional)"
                    aria-label="Change note"
                    disabled={!editor.canEdit}
                  />
                  {previewUrl(config, editor.content) && (
                    <button type="button" onClick={() => void preview()}>Preview</button>
                  )}
                  <button type="button" onClick={() => setShowVersions(!showVersions)} aria-pressed={showVersions}>
                    Versions
                  </button>
                  {editor.content.url && (
                    <a href={editor.content.url} target="_blank" rel="noreferrer">View live</a>
                  )}
                  <button type="button" className="studio-primary" onClick={() => void save()} disabled={!editor.canEdit || saving}>
                    {saving ? 'Saving…' : 'Save'}
                  </button>
                </div>
              ),
            }}
          />
        </EditorContext.Provider>
        {showVersions && (
          <VersionsPanel
            contentID={contentID}
            currentVersion={editor.content.version}
            onClose={() => setShowVersions(false)}
            onLoad={(blocks, version) => {
              show(blocks, loaded.definitions)
              setDirty(true)
              setMessage({ kind: 'info', text: `Version ${version} is in the editor. Save to make it the current version.` })
            }}
          />
        )}
      </div>
    </div>
  )
}
