/**
 * State shared by the left column (pages or blog) and the editor: the site shown, its pages, the section of the left
 * column, and navigation that asks before leaving unsaved changes
 */
import { createContext, useContext, type Dispatch, type SetStateAction } from 'react'
import type { Site, TreePage } from '../types'

/** What the left column shows */
export type Section = 'pages' | 'blog'

export const SECTION_LABELS: Record<Section, string> = { pages: 'Pages', blog: 'Blog' }

export interface WorkspaceValue {
  site: Site | undefined
  setSiteID: (siteID: string) => void
  pages: TreePage[]
  setPages: Dispatch<SetStateAction<TreePage[]>>
  loading: boolean
  loadError: string
  /** Load the pages of the site again, e.g. after a save changed a status; the blog list reloads too */
  reload: () => Promise<void>
  /** Counts the reloads: lists that load their own data (the blog) reload when it changes */
  revision: number
  section: Section
  showSection: (section: Section) => void
  /** Content open in the editor ("" when none) */
  currentID: string
  /** Open content in the editor; asks first if the editor has unsaved changes */
  openPage: (contentID: string) => void
  /** Navigate within Studio; asks first if the editor has unsaved changes */
  goTo: (path: string) => void
  /** The editor reports whether it has unsaved changes */
  setUnsaved: (unsaved: boolean) => void
}

export const WorkspaceContext = createContext<WorkspaceValue | null>(null)

export function useWorkspace(): WorkspaceValue {
  const value = useContext(WorkspaceContext)
  if (!value) throw new Error('useWorkspace() needs <Workspace>')
  return value
}
