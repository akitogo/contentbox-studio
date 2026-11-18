/**
 * App-wide context: page config, API client, the logged-in author and the sites
 */
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import type { ApiClient } from './api'
import type { StudioConfig } from './config'
import type { Me, Site } from './types'

export interface Studio {
  config: StudioConfig
  api: ApiClient
  me: Me
  sites: Site[]
}

const StudioContext = createContext<Studio | null>(null)

export function useStudio(): Studio {
  const studio = useContext(StudioContext)
  if (!studio) {
    throw new Error('useStudio() outside <StudioProvider>')
  }
  return studio
}

type Loading = { status: 'loading' } | { status: 'error'; message: string } | { status: 'ready'; me: Me; sites: Site[] }

export function StudioProvider({
  config,
  api,
  children,
}: {
  config: StudioConfig
  api: ApiClient
  children: ReactNode
}) {
  const [state, setState] = useState<Loading>({ status: 'loading' })

  useEffect(() => {
    let cancelled = false
    Promise.all([api.get<Me>(`${config.studioApi}/me`), api.get<Site[]>(`${config.studioApi}/sites`)])
      .then(([me, sites]) => !cancelled && setState({ status: 'ready', me, sites }))
      .catch((error: unknown) => {
        if (!cancelled) setState({ status: 'error', message: error instanceof Error ? error.message : String(error) })
      })
    return () => {
      cancelled = true
    }
  }, [api, config])

  if (state.status === 'loading') return <p className="studio-muted studio-center">Loading…</p>
  if (state.status === 'error') {
    return (
      <p className="studio-error studio-center" role="alert">
        Could not load Studio: {state.message}
      </p>
    )
  }
  return (
    <StudioContext.Provider value={{ config, api, me: state.me, sites: state.sites }}>{children}</StudioContext.Provider>
  )
}

/** Error text of anything thrown */
export function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}
