/**
 * Puck overrides that need Studio's editor state: the header (title, status, undo/redo, sidebar toggles, actions)
 * and the right column without a selected block (the content's settings). They are stable module-level components
 * (overrides are remounted when their identity changes) and get what they need from EditorActionsContext.
 */
import { createUsePuck } from '@puckeditor/core'
import { Eye, History, LayoutTemplate, PanelLeft, PanelRight, Redo2, Save, Undo2 } from 'lucide-react'
import { createContext, useContext, type ReactNode } from 'react'
import type { ContentDetails } from '../types'
import { Badge, Button, IconButton, Input } from '../ui'
import { PageDetails } from './PageDetails'

export interface EditorActions {
  content: ContentDetails
  canEdit: boolean
  dirty: boolean
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

const usePuck = createUsePuck()

/** Label that is hidden when the editor is narrow (the button keeps its accessible name through aria-label) */
const Label = ({ children }: { children: ReactNode }) => <span className="hidden @5xl:inline">{children}</span>

export function EditorHeader() {
  const actions = useContext(EditorActionsContext)
  const history = usePuck((state) => state.history)
  const dispatch = usePuck((state) => state.dispatch)
  const leftVisible = usePuck((state) => state.appState.ui.leftSideBarVisible)
  const rightVisible = usePuck((state) => state.appState.ui.rightSideBarVisible)
  if (!actions) return <></>
  const { content } = actions

  return (
    <div className="@container border-b border-slate-200 bg-white">
      <div className="flex h-12 items-center gap-2 px-2">
        <IconButton
          label={leftVisible ? 'Hide the blocks column' : 'Show the blocks column'}
          active={leftVisible}
          onClick={() => dispatch({ type: 'setUi', ui: { leftSideBarVisible: !leftVisible } })}
        >
          <PanelLeft className="size-4" />
        </IconButton>
        <h1 className="ml-1 min-w-0 truncate text-sm font-semibold text-slate-900" title={content.title}>
          {content.title}
        </h1>
        <Badge tone={content.isPublished ? 'success' : 'neutral'}>{content.isPublished ? 'Published' : 'Draft'}</Badge>
        <span className="hidden text-xs whitespace-nowrap text-slate-400 @3xl:inline">
          Version {content.version}
          {actions.dirty && <span className="ml-1.5 text-amber-600">· unsaved</span>}
        </span>
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
            aria-label="Versions"
            title="Versions"
          >
            <History className="size-3.5" />
            <Label>Versions</Label>
          </Button>
          <Button size="sm" variant="ghost" onClick={actions.saveAsTemplate} disabled={!actions.canEdit} aria-label="Save as template" title="Save as template">
            <LayoutTemplate className="size-3.5" />
            <Label>Save as template</Label>
          </Button>
          <Button size="sm" onClick={actions.togglePublished} disabled={!actions.canEdit}>
            {content.isPublished ? 'Unpublish' : 'Publish'}
          </Button>
          <Button size="sm" variant="primary" onClick={actions.save} disabled={!actions.canEdit || actions.saving}>
            <Save className="size-3.5" />
            {actions.saving ? 'Saving…' : 'Save'}
          </Button>
          <IconButton
            label={rightVisible ? 'Hide the fields column' : 'Show the fields column'}
            active={rightVisible}
            onClick={() => dispatch({ type: 'setUi', ui: { rightSideBarVisible: !rightVisible } })}
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
  return <PageDetails key={actions.content.contentID} content={actions.content} canEdit={actions.canEdit} />
}
