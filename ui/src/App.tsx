import { lazy, Suspense } from 'react'
import { BrowserRouter, Route, Routes } from 'react-router'
import type { ApiClient } from './api'
import { basePath, type StudioConfig } from './config'
import { TreePage } from './pages/TreePage'
import { StudioProvider } from './studio'
import { Loading } from './ui'

// The editor (Puck, TipTap) is large: load it only when content is opened
const EditorPage = lazy(() => import('./pages/EditorPage').then((module) => ({ default: module.EditorPage })))

export function App({ config, api }: { config: StudioConfig; api: ApiClient }) {
  return (
    <StudioProvider config={config} api={api}>
      <BrowserRouter basename={basePath(config)}>
        <Suspense fallback={<Loading>Loading the editor…</Loading>}>
          <Routes>
            <Route path="/" element={<TreePage />} />
            <Route path="/content/:contentID" element={<EditorPage />} />
          </Routes>
        </Suspense>
      </BrowserRouter>
    </StudioProvider>
  )
}
