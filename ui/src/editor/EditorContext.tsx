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
}

export const EditorContext = createContext<EditorContextValue>({
  siteID: '',
  canEditHtml: false,
  canEdit: false,
  contentStoreItems: [],
  pages: [],
})

export const useEditorContext = () => useContext(EditorContext)
