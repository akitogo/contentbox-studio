import { Puck } from '@puckeditor/core'
import '@puckeditor/core/no-external.css'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useParams } from 'react-router'
import { ApiError } from '../api'
import type { ParsedBlock } from '../blocks/format'
import { fromPuckData, toPuckData, typesByName, type BlockNotice, type PuckData } from '../editor/blocksData'
import { CanvasStyles } from '../editor/CanvasStyles'
import { EditorActionsContext, EditorFields, EditorHeader, rememberedPanels, type EditorActions } from '../editor/EditorActions'
import { EditorContext, type EditorContextValue } from '../editor/EditorContext'
import { openPreview, previewFields, previewUrl } from '../editor/preview'
import { buildConfig } from '../editor/puckConfig'
import { SaveTemplateDialog } from '../editor/SaveTemplateDialog'
import { VersionsPanel } from '../editor/VersionsPanel'
import { messageOf, useStudio } from '../studio'
import type { BlockDefinition, BlockError, EditorContent, TreePage } from '../types'
import { Alert, Button, Loading } from '../ui'
import { useWorkspace } from '../workspace/WorkspaceContext'

const NOTICE_TEXT: Record<BlockNotice['status'], string> = {
  legacy: 'HTML written outside Studio, shown as an HTML block',
  invalid: 'a block Studio could not read, shown as an HTML block',
  modified: 'changed outside Studio; saving renders it again from its fields and drops those changes',
}

// Stable (module-level): Puck remounts overrides whose identity changes
const PUCK_OVERRIDES = { header: EditorHeader, iframe: CanvasStyles, fields: EditorFields }
// The canvas gets the theme's CSS (CanvasStyles), not Studio's
const PUCK_IFRAME = { enabled: true, syncHostStyles: false }

interface Loaded {
  editor: EditorContent
  definitions: BlockDefinition[]
  context: EditorContextValue
}

type Message = { tone: 'danger' | 'success' | 'info'; text: string }

/** Route element: a fresh editor for each content (no state carried over from the previous one) */
export function EditorPage() {
  const { contentID = '' } = useParams()
  return <ContentEditor key={contentID} contentID={contentID} />
}

function ContentEditor({ contentID }: { contentID: string }) {
  const { config, api } = useStudio()
  const { setUnsaved, setSiteID, reload: reloadTree, goTo } = useWorkspace()
  const [loaded, setLoaded] = useState<Loaded | null>(null)
  const [initial, setInitial] = useState<{ data: PuckData; notices: BlockNotice[]; key: number } | null>(null)
  const [loadError, setLoadError] = useState('')
  const [message, setMessage] = useState<Message | null>(null)
  const [errors, setErrors] = useState<BlockError[]>([])
  const [changelog, setChangelog] = useState('')
  const [saving, setSaving] = useState(false)
  const [dirty, setDirty] = useState(false)
  const [showVersions, setShowVersions] = useState(false)
  const [templateDialog, setTemplateDialog] = useState(false)
  const current = useRef<PuckData | null>(null)
  const [puckUi] = useState(rememberedPanels)

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
        const [definitions, pages, contentStoreItems, themeStylesheets] = await Promise.all([
          api.get<BlockDefinition[]>(`${config.studioApi}/blocks?site=${site}`),
          api.get<TreePage[]>(`${config.studioApi}/sites/${site}/tree`),
          api.get<{ slug: string; title: string }[]>(`${config.studioApi}/sites/${site}/contentstore`),
          api.get<string[]>(`${config.studioApi}/sites/${site}/styles`).catch(() => [] as string[]),
        ])
        // Core block styles first: the theme's CSS comes later and wins anyway (blocks.css uses :where())
        const stylesheets = [config.blockStyles, ...themeStylesheets].filter(Boolean)
        if (cancelled) return
        // The tree shows the site of the open content
        setSiteID(editor.content.siteID)
        setLoaded({
          editor,
          definitions,
          context: { siteID: editor.content.siteID, canEdit: editor.canEdit, canEditHtml: editor.canEditHtml, pages, contentStoreItems, stylesheets },
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
  }, [api, config, contentID, show, setSiteID])

  // Warn before leaving with unsaved changes: within Studio (workspace) and when closing or reloading the page
  useEffect(() => {
    setUnsaved(dirty)
    return () => setUnsaved(false)
  }, [dirty, setUnsaved])

  useEffect(() => {
    if (!dirty) return
    const warn = (event: BeforeUnloadEvent) => event.preventDefault()
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [dirty])

  const puckConfig = useMemo(() => (loaded ? buildConfig(loaded.definitions, loaded.editor.canEditHtml) : null), [loaded])

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
      setMessage({ tone: 'success', text: `Saved as version ${result.content.version}.` })
      void reloadTree()
    } catch (error) {
      if (error instanceof ApiError && error.status === 422) {
        setErrors((error.data as { errors?: BlockError[] } | undefined)?.errors ?? [])
        setMessage({ tone: 'danger', text: 'Not saved: some blocks need attention.' })
      } else {
        setMessage({ tone: 'danger', text: `Not saved: ${messageOf(error)}` })
      }
    } finally {
      setSaving(false)
    }
  }

  async function togglePublished() {
    if (!loaded) return
    try {
      const result = await api.put<EditorContent>(`${config.studioApi}/content/${contentID}/status`, {
        isPublished: !loaded.editor.content.isPublished,
      })
      setLoaded({ ...loaded, editor: { ...loaded.editor, content: result.content } })
      setMessage({ tone: 'success', text: result.content.isPublished ? 'Published.' : 'Unpublished: the page is a draft again.' })
      void reloadTree()
    } catch (error) {
      setMessage({ tone: 'danger', text: messageOf(error) })
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
      setMessage({ tone: 'danger', text: `Preview failed: ${messageOf(error)}` })
    }
  }

  if (loadError) {
    return (
      <div className="mx-auto mt-16 grid max-w-lg gap-4 px-4">
        <Alert tone="danger">Could not open the content: {loadError}</Alert>
        <Button className="justify-self-start" onClick={() => goTo('/')}>
          Back to the pages
        </Button>
      </div>
    )
  }
  if (!loaded || !initial || !puckConfig) return <Loading>Loading the editor…</Loading>

  const { editor } = loaded
  const blockLabel = (id: string) => {
    const item = current.current?.content.find((block) => block.props.id === id)
    return item ? (loaded.definitions.find((definition) => definition.name === item.type)?.label ?? item.type) : id
  }

  const messages = (message || errors.length > 0 || initial.notices.length > 0 || !editor.canEdit) && (
    <div className="grid gap-2 border-t border-slate-100 px-4 py-2">
      {!editor.canEdit && <Alert tone="warning">You can look at this content but not save it (missing permission).</Alert>}
      {message && (
        <Alert tone={message.tone} onClose={() => setMessage(null)}>
          {message.text}
          {errors.length > 0 && (
            <ul className="mt-1 list-disc pl-4">
              {errors.map((error, index) => (
                <li key={index}>
                  {blockLabel(error.blockID)}: {error.message}
                </li>
              ))}
            </ul>
          )}
        </Alert>
      )}
      {initial.notices.length > 0 && (
        <Alert tone="info">
          <ul className="list-disc pl-4">
            {initial.notices.map((notice) => (
              <li key={notice.id}>
                Block “{notice.type}”: {NOTICE_TEXT[notice.status]}
              </li>
            ))}
          </ul>
        </Alert>
      )}
    </div>
  )

  const actions: EditorActions = {
    content: editor.content,
    canEdit: editor.canEdit,
    dirty,
    saving,
    changelog,
    setChangelog,
    save: () => void save(),
    preview: previewUrl(config, editor.content) ? () => void preview() : null,
    togglePublished: () => void togglePublished(),
    toggleVersions: () => setShowVersions(!showVersions),
    showVersions,
    saveAsTemplate: () => setTemplateDialog(true),
    messages,
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="flex min-h-0 flex-1">
        <div className="min-h-0 min-w-0 flex-1 overflow-hidden [&>*]:h-full">
          <EditorContext.Provider value={loaded.context}>
            <EditorActionsContext.Provider value={actions}>
              <Puck
                key={initial.key}
                config={puckConfig}
                data={initial.data}
                onChange={(data) => {
                  current.current = data as PuckData
                  setDirty(true)
                }}
                overrides={PUCK_OVERRIDES}
                ui={puckUi}
                iframe={PUCK_IFRAME}
                permissions={{ edit: editor.canEdit, insert: editor.canEdit, delete: editor.canEdit, drag: editor.canEdit, duplicate: editor.canEdit }}
              />
            </EditorActionsContext.Provider>
          </EditorContext.Provider>
        </div>
        {showVersions && (
          <VersionsPanel
            contentID={contentID}
            currentVersion={editor.content.version}
            onClose={() => setShowVersions(false)}
            onLoad={(blocks, version) => {
              show(blocks, loaded.definitions)
              setDirty(true)
              setMessage({ tone: 'info', text: `Version ${version} is in the editor. Save to make it the current version.` })
            }}
          />
        )}
      </div>
      {templateDialog && (
        <SaveTemplateDialog
          contentID={contentID}
          title={editor.content.title}
          dirty={dirty}
          onClose={() => setTemplateDialog(false)}
          onSaved={(name) => {
            setTemplateDialog(false)
            setMessage({ tone: 'success', text: `Saved as the template “${name}”. New pages can start from it.` })
          }}
        />
      )}
    </div>
  )
}
