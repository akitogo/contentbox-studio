/**
 * What the custom fields need from the editor page: the site, permissions and lists loaded once
 */
import { createContext, useContext } from 'react'
import type { TreePage } from '../types'

export interface EditorContextValue {
  siteID: string
  canEditHtml: boolean
  canEdit: boolean
  contentStoreItems: { slug: string; title: string }[]
  pages: TreePage[]
  /** Stylesheets of the site's theme for the canvas (GET /sites/:site/styles) */
  stylesheets: string[]
}

export const EditorContext = createContext<EditorContextValue>({
  siteID: '',
  canEditHtml: false,
  canEdit: false,
  contentStoreItems: [],
  pages: [],
  stylesheets: [],
})

export const useEditorContext = () => useContext(EditorContext)
