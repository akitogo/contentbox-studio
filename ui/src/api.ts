import type { Tokens } from './config'

export class ApiError extends Error {
  readonly status: number

  constructor(status: number, messages: string[]) {
    super(messages.join(' ') || `Request failed with status ${status}`)
    this.name = 'ApiError'
    this.status = status
  }
}

/** Response envelope of ColdBox's RestHandler, used by /cbapi/v1 and /cbstudio/api */
interface Envelope<T> {
  data: T
  error: boolean
  messages: string[]
}

type FetchFn = (input: string, init: RequestInit) => Promise<Response>

/**
 * JSON client for the ContentBox and Studio APIs.
 *
 * Every request carries the access token and the refresh token. When the access token has expired, cbsecurity's
 * JWT validator refreshes both and returns them in the x-auth-token and x-refresh-token response headers; the
 * client keeps those for the next requests.
 */
export class ApiClient {
  private tokens: Tokens
  private readonly fetchFn: FetchFn

  constructor(tokens: Tokens, fetchFn: FetchFn = (input, init) => fetch(input, init)) {
    this.tokens = { ...tokens }
    this.fetchFn = fetchFn
  }

  get<T>(url: string): Promise<T> {
    return this.request<T>(url)
  }

  post<T>(url: string, data?: unknown): Promise<T> {
    return this.request<T>(url, {
      method: 'POST',
      body: data === undefined ? undefined : JSON.stringify(data),
    })
  }

  put<T>(url: string, data?: unknown): Promise<T> {
    return this.request<T>(url, {
      method: 'PUT',
      body: data === undefined ? undefined : JSON.stringify(data),
    })
  }

  delete<T>(url: string): Promise<T> {
    return this.request<T>(url, { method: 'DELETE' })
  }

  async request<T>(url: string, init: RequestInit = {}): Promise<T> {
    const headers = new Headers(init.headers)
    headers.set('Accept', 'application/json')
    headers.set('Authorization', `Bearer ${this.tokens.access_token}`)
    headers.set('x-refresh-token', this.tokens.refresh_token)
    if (typeof init.body === 'string') {
      headers.set('Content-Type', 'application/json')
    }

    const response = await this.fetchFn(url, { ...init, headers, credentials: 'same-origin' })
    this.keepRefreshedTokens(response.headers)

    const body = (await response.json().catch(() => null)) as Envelope<T> | null
    if (!response.ok || !body || body.error) {
      throw new ApiError(response.status, body?.messages ?? [])
    }
    return body.data
  }

  private keepRefreshedTokens(headers: Headers) {
    const accessToken = headers.get('x-auth-token')
    const refreshToken = headers.get('x-refresh-token')
    if (accessToken && refreshToken) {
      this.tokens = { access_token: accessToken, refresh_token: refreshToken }
    }
  }
}
