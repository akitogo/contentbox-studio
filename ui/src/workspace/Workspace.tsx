import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Outlet, useMatch, useNavigate, useSearchParams } from 'react-router'
import { Header } from '../components/Header'
import { store, stored } from '../lib/storage'
import { messageOf, useStudio } from '../studio'
import type { TreePage } from '../types'
import { Button, Dialog, Select } from '../ui'
import { SidePane } from './SidePane'
import { WorkspaceContext, type Section, type WorkspaceValue } from './WorkspaceContext'

const SECTION_KEY = 'cbstudio.section'

/**
 * Studio's layout: the pages (site tree) or the blog fill the screen until content is opened, then they become a
 * column (resizable, collapsible) next to the editor
 */
export function Workspace() {
  const { config, api, sites } = useStudio()
  const [params] = useSearchParams()
  const navigate = useNavigate()
  const [siteID, setSiteID] = useState(() => (sites.find((item) => item.slug === params.get('site')) ?? sites[0])?.siteID ?? '')
  const site = sites.find((item) => item.siteID === siteID) ?? sites[0]
  const [pages, setPages] = useState<TreePage[]>([])
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState('')
  const [pendingPath, setPendingPath] = useState<string | null>(null)
  const [revision, setRevision] = useState(0)
  const [section, setSection] = useState<Section>(() => (stored(SECTION_KEY) === 'blog' ? 'blog' : 'pages'))
  const unsaved = useRef(false)
  const currentID = useMatch('/content/:contentID')?.params.contentID ?? ''

  const loadPages = useCallback(async () => {
    if (!site) return
    setLoading(true)
    try {
      setPages(await api.get<TreePage[]>(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/tree`))
      setLoadError('')
    } catch (error) {
      setLoadError(messageOf(error))
    } finally {
      setLoading(false)
    }
  }, [api, config, site])

  useEffect(() => {
    setPages([])
    void loadPages()
  }, [loadPages])

  // After changes (save, publish, new content): the pages, and lists with their own data (the blog) via revision
  const reload = useCallback(async () => {
    setRevision((value) => value + 1)
    await loadPages()
  }, [loadPages])

  const showSection = useCallback((value: Section) => {
    setSection(value)
    store(SECTION_KEY, value)
  }, [])

  const goTo = useCallback(
    (path: string) => {
      if (unsaved.current) setPendingPath(path)
      else navigate(path)
    },
    [navigate],
  )

  const value = useMemo<WorkspaceValue>(
    () => ({
      site,
      setSiteID,
      pages,
      setPages,
      loading,
      loadError,
      reload,
      revision,
      section,
      showSection,
      currentID,
      openPage: (contentID: string) => goTo(`/content/${contentID}`),
      goTo,
      setUnsaved: (value: boolean) => {
        unsaved.current = value
      },
    }),
    [site, pages, loading, loadError, reload, revision, section, showSection, currentID, goTo],
  )

  return (
    <WorkspaceContext.Provider value={value}>
      <div className="flex h-screen flex-col overflow-hidden">
        <Header>
          {sites.length > 1 && (
            <Select className="h-8 w-56" value={site?.siteID ?? ''} onChange={(event) => setSiteID(event.target.value)} aria-label="Site">
              {sites.map((item) => (
                <option key={item.siteID} value={item.siteID}>
                  {item.name}
                </option>
              ))}
            </Select>
          )}
        </Header>
        <div className="flex min-h-0 flex-1">
          <SidePane mode={currentID ? 'column' : 'full'} />
          {currentID && (
            <main className="min-h-0 min-w-0 flex-1">
              <Outlet />
            </main>
          )}
        </div>
      </div>

      {pendingPath !== null && (
        <Dialog
          title="Leave without saving?"
          onClose={() => setPendingPath(null)}
          footer={
            <>
              <Button onClick={() => setPendingPath(null)}>Keep editing</Button>
              <Button
                variant="danger"
                onClick={() => {
                  unsaved.current = false
                  setPendingPath(null)
                  navigate(pendingPath)
                }}
              >
                Discard changes
              </Button>
            </>
          }
        >
          <p className="text-sm text-slate-600">The content in the editor has changes that are not saved. They are lost if you leave.</p>
        </Dialog>
      )}
    </WorkspaceContext.Provider>
  )
}
