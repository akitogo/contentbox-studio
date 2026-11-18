import { lazy, Suspense } from 'react'
import { BrowserRouter, Route, Routes } from 'react-router'
import type { ApiClient } from './api'
import { basePath, type StudioConfig } from './config'
import { StudioProvider } from './studio'
import { Loading } from './ui'
import { Workspace } from './workspace/Workspace'

// The editor (Puck, TipTap) is large: load it only when content is opened
const EditorPage = lazy(() => import('./pages/EditorPage').then((module) => ({ default: module.EditorPage })))

export function App({ config, api }: { config: StudioConfig; api: ApiClient }) {
  return (
    <StudioProvider config={config} api={api}>
      <BrowserRouter basename={basePath(config)}>
        <Routes>
          {/* The site tree; content opens next to it */}
          <Route element={<Workspace />}>
            <Route index element={null} />
            <Route
              path="content/:contentID"
              element={
                <Suspense fallback={<Loading>Loading the editor…</Loading>}>
                  <EditorPage />
                </Suspense>
              }
            />
          </Route>
        </Routes>
      </BrowserRouter>
    </StudioProvider>
  )
}
