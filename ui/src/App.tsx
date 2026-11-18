import { BrowserRouter, Route, Routes } from 'react-router'
import type { ApiClient } from './api'
import { basePath, type StudioConfig } from './config'
import { EditorPage } from './pages/EditorPage'
import { TreePage } from './pages/TreePage'
import { StudioProvider } from './studio'

export function App({ config, api }: { config: StudioConfig; api: ApiClient }) {
  return (
    <StudioProvider config={config} api={api}>
      <BrowserRouter basename={basePath(config)}>
        <Routes>
          <Route path="/" element={<TreePage />} />
          <Route path="/content/:contentID" element={<EditorPage />} />
        </Routes>
      </BrowserRouter>
    </StudioProvider>
  )
}
