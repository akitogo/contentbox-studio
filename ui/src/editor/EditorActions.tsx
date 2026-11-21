/**
 * Puck overrides that need Studio's editor state: the header (title, status, undo/redo, sidebar toggles, actions)
 * and the right column without a selected block (the content's settings). They are stable module-level components
 * (overrides are remounted when their identity changes) and get what they need from EditorActionsContext.
 */
import { createUsePuck } from '@puckeditor/core'
import { Eye, History, LayoutTemplate, PanelLeft, PanelRight, Redo2, Save, Undo2 } from 'lucide-react'
import { createContext, useContext, useEffect, type ReactNode } from 'react'
import type { ContentDetails } from '../types'
import { STATUS } from '../workspace/status'
import type { ContentSettings } from './contentSettings'
import { store, stored } from '../lib/storage'
import { Badge, Button, IconButton, Input, Switch } from '../ui'
import { PageDetails } from './PageDetails'

export interface EditorActions {
  content: ContentDetails
  canEdit: boolean
  canPublish: boolean
  /** Unsaved changes: blocks or settings */
  dirty: boolean
  /** The content's settings as edited (saved with the blocks) */
  settings: ContentSettings | null
  setSettings: (settings: ContentSettings) => void
  saving: boolean
  changelog: string
  setChangelog: (value: string) => void
  save: () => void
  preview: (() => void) | null
  togglePublished: () => void
  toggleVersions: () => void
  showVersions: boolean
  saveAsTemplate: () => void
  messages: ReactNode
}

export const EditorActionsContext = createContext<EditorActions | null>(null)

/** What publishing a content type needs */
const ADMIN_PERMISSION: Record<ContentDetails['contentType'], string> = { page: 'PAGES_ADMIN', entry: 'ENTRIES_ADMIN', contentStore: 'CONTENTSTORE_ADMIN' }

const usePuck = createUsePuck()

/** Remembered per browser, so they stay when other content is opened: visibility of Puck's columns, the viewport */
const PANELS = { left: 'cbstudio.blocksHidden', right: 'cbstudio.fieldsHidden' }
const VIEWPORT = 'cbstudio.viewport'

/** The canvas width last chosen (a viewport's width in px, or "100%" for full width), if any */
export function rememberedViewport(): number | '100%' | null {
  const value = stored(VIEWPORT)
  if (value === '100%') return value
  const width = Number(value)
  return Number.isInteger(width) && width > 0 ? width : null
}

/** Puck's initial UI state (its `ui` prop) with what is remembered */
export function rememberedUi() {
  const width = rememberedViewport()
  return {
    leftSideBarVisible: stored(PANELS.left) !== '1',
    rightSideBarVisible: stored(PANELS.right) !== '1',
    // Puck merges only the top level: the whole viewports object, as in Puck's default (it fills in the options)
    ...(width ? { viewports: { current: { width, height: 'auto' as const }, options: [], controlsVisible: true } } : {}),
  }
}

/** Label that is hidden when the editor is narrow (the button keeps its accessible name through aria-label) */
const Label = ({ children }: { children: ReactNode }) => <span className="hidden @5xl:inline">{children}</span>

export function EditorHeader() {
  const actions = useContext(EditorActionsContext)
  const history = usePuck((state) => state.history)
  const dispatch = usePuck((state) => state.dispatch)
  const leftVisible = usePuck((state) => state.appState.ui.leftSideBarVisible)
  const rightVisible = usePuck((state) => state.appState.ui.rightSideBarVisible)
  const viewportWidth = usePuck((state) => state.appState.ui.viewports.current.width)
  useEffect(() => {
    store(VIEWPORT, String(viewportWidth))
  }, [viewportWidth])
  if (!actions) return <></>
  const { content } = actions

  return (
    <div className="@container border-b border-slate-200 bg-white">
      <div className="flex h-12 items-center gap-2 px-2">
        <IconButton
          label={leftVisible ? 'Hide the blocks column' : 'Show the blocks column'}
          active={leftVisible}
          onClick={() => {
            dispatch({ type: 'setUi', ui: { leftSideBarVisible: !leftVisible } })
            store(PANELS.left, leftVisible ? '1' : '0')
          }}
        >
          <PanelLeft className="size-4" />
        </IconButton>
        <h1 className="ml-1 min-w-0 truncate text-sm font-semibold text-slate-900" title={actions.settings?.title ?? content.title}>
          {actions.settings?.title || content.title}
        </h1>
        <Badge tone={STATUS[content.status].tone}>{STATUS[content.status].label}</Badge>
        {actions.dirty && <span className="hidden text-xs whitespace-nowrap text-amber-600 @3xl:inline">unsaved</span>}
        {actions.dirty && <span className="size-2 shrink-0 rounded-full bg-amber-500 @3xl:hidden" title="Unsaved changes" />}
        <div className="flex items-center">
          <IconButton label="Undo" onClick={() => history.back()} disabled={!history.hasPast}>
            <Undo2 className="size-4" />
          </IconButton>
          <IconButton label="Redo" onClick={() => history.forward()} disabled={!history.hasFuture}>
            <Redo2 className="size-4" />
          </IconButton>
        </div>

        <div className="ml-auto flex shrink-0 items-center gap-1.5">
          <Input
            className="hidden h-8 w-40 @4xl:block @6xl:w-56"
            value={actions.changelog}
            onChange={(event) => actions.setChangelog(event.target.value)}
            placeholder="What changed? (optional)"
            aria-label="Change note"
            disabled={!actions.canEdit}
          />
          {actions.preview && (
            <Button size="sm" variant="ghost" onClick={actions.preview} aria-label="Preview" title="Preview with the site's layout">
              <Eye className="size-3.5" />
              <Label>Preview</Label>
            </Button>
          )}
          <Button
            size="sm"
            variant={actions.showVersions ? 'secondary' : 'ghost'}
            aria-pressed={actions.showVersions}
            onClick={actions.toggleVersions}
            aria-label={`Versions (current: version ${content.version})`}
            title={`Versions (current: version ${content.version})`}
          >
            <History className="size-3.5" />
            <Label>Versions</Label>
            <Badge className="px-1.5 py-0 text-[11px] tabular-nums">{content.version}</Badge>
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={actions.saveAsTemplate}
            disabled={!actions.canPublish}
            aria-label="Save as template"
            title={actions.canPublish ? 'Save as template' : `Save as template: needs the ${ADMIN_PERMISSION[content.contentType]} permission`}
          >
            <LayoutTemplate className="size-3.5" />
            <Label>Save as template</Label>
          </Button>
          {/* Pages only; a setting like the search engine fields, saved with Save */}
          {actions.settings && actions.settings.showInMenu !== null && (
            <Switch
              checked={actions.settings.showInMenu}
              onChange={(showInMenu) => actions.settings && actions.setSettings({ ...actions.settings, showInMenu })}
              label={<Label>Menu</Label>}
              name="Show in the site's menu"
              title={
                actions.canEdit
                  ? `${actions.settings.showInMenu ? "In the site's menu" : "Not in the site's menu"} (saved with Save)`
                  : 'Needs the right to edit this page'
              }
              disabled={!actions.canEdit}
            />
          )}
          <Button
            size="sm"
            onClick={actions.togglePublished}
            disabled={!actions.canPublish}
            title={actions.canPublish ? undefined : `Publishing needs the ${ADMIN_PERMISSION[content.contentType]} permission`}
          >
            {content.isPublished ? 'Unpublish' : 'Publish'}
          </Button>
          <Button size="sm" variant="primary" onClick={actions.save} disabled={!actions.canEdit || actions.saving}>
            <Save className="size-3.5" />
            {actions.saving ? 'Saving…' : 'Save'}
          </Button>
          <IconButton
            label={rightVisible ? 'Hide the fields column' : 'Show the fields column'}
            active={rightVisible}
            onClick={() => {
              dispatch({ type: 'setUi', ui: { rightSideBarVisible: !rightVisible } })
              store(PANELS.right, rightVisible ? '1' : '0')
            }}
          >
            <PanelRight className="size-4" />
          </IconButton>
        </div>
      </div>
      {actions.messages}
    </div>
  )
}

/** Right column: the block's fields, or the content's settings when no block is selected */
// itemSelector is Puck's selection (not exported as a type); null or missing: no block selected
export function EditorFields({ children, itemSelector }: { children: ReactNode; itemSelector?: unknown }) {
  const actions = useContext(EditorActionsContext)
  if (itemSelector || !actions) return <>{children}</>
  return (
    <PageDetails
      key={actions.content.contentID}
      content={actions.content}
      canEdit={actions.canEdit}
      settings={actions.settings}
      onSettingsChange={actions.setSettings}
    />
  )
}
