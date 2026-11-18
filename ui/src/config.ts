export interface Tokens {
  access_token: string
  refresh_token: string
}

/** Rendered into the page by the module (handlers/Home.cfc) */
export interface StudioConfig {
  version: string
  /** URL of the app itself, e.g. http://example.com/cbstudio; the router uses its path */
  appBase: string
  /** Studio API, e.g. http://example.com/cbstudio/api */
  studioApi: string
  /** ContentBox REST API, e.g. http://example.com/cbapi/v1 */
  contentboxApi: string
  adminUrl: string
  logoutUrl: string
  tokens: Tokens
  /** ContentBox's preview checks it: hash of the author id */
  previewHash: string
  /** ContentBox's /__page_preview and /__entry_preview */
  pagePreview: string
  entryPreview: string
}

const withoutTrailingSlash = (url: string) => url.replace(/\/+$/, '')

export function parseConfig(json: string): StudioConfig {
  const config = JSON.parse(json) as StudioConfig
  if (!config.tokens?.access_token || !config.tokens?.refresh_token) {
    throw new Error('ContentBox Studio: the page config has no tokens')
  }
  return {
    ...config,
    appBase: withoutTrailingSlash(config.appBase ?? ''),
    studioApi: withoutTrailingSlash(config.studioApi),
    contentboxApi: withoutTrailingSlash(config.contentboxApi),
  }
}

export function readConfig(doc: Document = document): StudioConfig {
  const element = doc.getElementById('cbstudio-config')
  if (!element?.textContent) {
    throw new Error('ContentBox Studio: #cbstudio-config is missing from the page')
  }
  return parseConfig(element.textContent)
}

/** Path of the app for the router, e.g. /cbstudio */
export function basePath(config: StudioConfig): string {
  try {
    return new URL(config.appBase).pathname.replace(/\/+$/, '') || '/'
  } catch {
    return '/cbstudio'
  }
}
