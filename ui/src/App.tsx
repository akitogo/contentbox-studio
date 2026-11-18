import { useEffect, useState } from 'react'
import type { ApiClient } from './api'
import type { StudioConfig } from './config'

interface Me {
  authorID: string
  username: string
  name: string
  email: string
  role: string
  permissions: { siteTree: boolean; htmlBlocks: boolean }
}

interface Site {
  siteID: string
  slug: string
  name: string
  siteRoot: string
}

type State =
  | { status: 'loading' }
  | { status: 'error'; message: string }
  | { status: 'ready'; me: Me; sites: Site[] }

export function App({ config, api }: { config: StudioConfig; api: ApiClient }) {
  const [state, setState] = useState<State>({ status: 'loading' })

  useEffect(() => {
    let cancelled = false
    Promise.all([api.get<Me>(`${config.studioApi}/me`), api.get<Site[]>(`${config.studioApi}/sites`)])
      .then(([me, sites]) => !cancelled && setState({ status: 'ready', me, sites }))
      .catch((error: unknown) => {
        if (!cancelled) {
          setState({ status: 'error', message: error instanceof Error ? error.message : String(error) })
        }
      })
    return () => {
      cancelled = true
    }
  }, [api, config])

  async function logout() {
    try {
      await api.post(`${config.contentboxApi}/logout`)
    } finally {
      window.location.href = config.logoutUrl
    }
  }

  return (
    <div className="studio">
      <header className="studio-header">
        <span className="studio-brand">
          ContentBox Studio <small>{config.version}</small>
        </span>
        <nav className="studio-nav">
          {state.status === 'ready' && (
            <span className="studio-user">
              {state.me.name} <small>{state.me.role}</small>
            </span>
          )}
          <a href={config.adminUrl}>Classic admin</a>
          <button type="button" onClick={logout}>
            Log out
          </button>
        </nav>
      </header>

      <main className="studio-main">
        {state.status === 'loading' && <p className="studio-muted">Loading…</p>}
        {state.status === 'error' && (
          <p className="studio-error" role="alert">
            Could not load Studio: {state.message}
          </p>
        )}
        {state.status === 'ready' && (
          <>
            <section className="studio-panel">
              <h1>Sites</h1>
              <ul className="studio-list">
                {state.sites.map((site) => (
                  <li key={site.siteID}>
                    <strong>{site.name}</strong>{' '}
                    <a href={site.siteRoot} target="_blank" rel="noreferrer">
                      {site.siteRoot}
                    </a>
                  </li>
                ))}
              </ul>
            </section>
            <section className="studio-panel">
              <h2>Your Studio permissions</h2>
              <ul className="studio-list">
                <li>Edit the site tree: {state.me.permissions.siteTree ? 'yes' : 'no'}</li>
                <li>Raw HTML blocks: {state.me.permissions.htmlBlocks ? 'yes' : 'no'}</li>
              </ul>
              <p className="studio-muted">The site tree and the block editor come next.</p>
            </section>
          </>
        )}
      </main>
    </div>
  )
}
