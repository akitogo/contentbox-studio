/**
 * Puck's header override: one bar with the title, status, undo/redo and Studio's actions.
 * It is a stable module-level component (overrides are remounted when their identity changes) and gets what it
 * needs from EditorActionsContext.
 */
import { createUsePuck } from '@puckeditor/core'
import { Eye, History, LayoutTemplate, Redo2, Save, Undo2 } from 'lucide-react'
import { createContext, useContext, type ReactNode } from 'react'
import { Link } from 'react-router'
import type { ContentDetails } from '../types'
import { Badge, Button, IconButton, Input } from '../ui'

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

export function EditorHeader() {
  const actions = useContext(EditorActionsContext)
  const history = usePuck((state) => state.history)
  if (!actions) return <></>
  const { content } = actions

  return (
    <div className="border-b border-slate-200 bg-white">
      <div className="flex h-12 items-center gap-3 px-4">
        <nav className="flex min-w-0 items-center gap-2 text-sm" aria-label="Breadcrumb">
          <Link to={`/?site=${encodeURIComponent(content.siteSlug)}`} className="text-slate-500 no-underline hover:text-slate-900">
            Pages
          </Link>
          <span className="text-slate-300">/</span>
          <span className="truncate font-semibold text-slate-900">{content.title}</span>
        </nav>
        <Badge tone={content.isPublished ? 'success' : 'neutral'}>{content.isPublished ? 'Published' : 'Draft'}</Badge>
        <span className="text-xs whitespace-nowrap text-slate-400">
          Version {content.version}
          {actions.dirty && <span className="ml-1.5 text-amber-600">· unsaved changes</span>}
        </span>
        <div className="ml-1 flex items-center">
          <IconButton label="Undo" onClick={() => history.back()} disabled={!history.hasPast}>
            <Undo2 className="size-4" />
          </IconButton>
          <IconButton label="Redo" onClick={() => history.forward()} disabled={!history.hasFuture}>
            <Redo2 className="size-4" />
          </IconButton>
        </div>

        <div className="ml-auto flex items-center gap-2">
          <Input
            className="h-8 w-56"
            value={actions.changelog}
            onChange={(event) => actions.setChangelog(event.target.value)}
            placeholder="What changed? (optional)"
            aria-label="Change note"
            disabled={!actions.canEdit}
          />
          {actions.preview && (
            <Button size="sm" onClick={actions.preview}>
              <Eye className="size-3.5" />
              Preview
            </Button>
          )}
          <Button size="sm" variant={actions.showVersions ? 'secondary' : 'ghost'} aria-pressed={actions.showVersions} onClick={actions.toggleVersions}>
            <History className="size-3.5" />
            Versions
          </Button>
          <Button size="sm" variant="ghost" onClick={actions.saveAsTemplate} disabled={!actions.canEdit}>
            <LayoutTemplate className="size-3.5" />
            Save as template
          </Button>
          <Button size="sm" onClick={actions.togglePublished} disabled={!actions.canEdit}>
            {content.isPublished ? 'Unpublish' : 'Publish'}
          </Button>
          <Button size="sm" variant="primary" onClick={actions.save} disabled={!actions.canEdit || actions.saving}>
            <Save className="size-3.5" />
            {actions.saving ? 'Saving…' : 'Save'}
          </Button>
        </div>
      </div>
      {actions.messages}
    </div>
  )
}
