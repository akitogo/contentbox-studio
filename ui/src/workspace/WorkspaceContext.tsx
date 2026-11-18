/**
 * State shared by the site tree column and the editor: the site shown, its pages, and navigation that asks before
 * leaving unsaved changes
 */
import { createContext, useContext, type Dispatch, type SetStateAction } from 'react'
import type { Site, TreePage } from '../types'

export interface WorkspaceValue {
  site: Site | undefined
  setSiteID: (siteID: string) => void
  pages: TreePage[]
  setPages: Dispatch<SetStateAction<TreePage[]>>
  loading: boolean
  loadError: string
  /** Load the pages of the site again, e.g. after a save changed a status */
  reload: () => Promise<void>
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
