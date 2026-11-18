import { describe, expect, it, vi } from 'vitest'
import { ApiClient, ApiError } from './api'

const tokens = { access_token: 'access-1', refresh_token: 'refresh-1' }

function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), { status, headers })
}

const ok = (data: unknown = {}, headers: Record<string, string> = {}) =>
  jsonResponse({ data, error: false, messages: [] }, 200, headers)

function mockFetch(...responses: Response[]) {
  const fn = vi.fn<(input: string, init: RequestInit) => Promise<Response>>()
  for (const response of responses) {
    fn.mockResolvedValueOnce(response)
  }
  return fn
}

function initOf(fetchFn: ReturnType<typeof mockFetch>, call = 0): RequestInit {
  const init = fetchFn.mock.calls[call]?.[1]
  if (!init) {
    throw new Error(`fetch call ${call} did not happen`)
  }
  return init
}

const headersOf = (fetchFn: ReturnType<typeof mockFetch>, call = 0) => initOf(fetchFn, call).headers as Headers

describe('ApiClient', () => {
  it('sends both tokens and returns the data of the envelope', async () => {
    const fetchFn = mockFetch(ok({ name: 'Ada' }))
    const api = new ApiClient(tokens, fetchFn)

    await expect(api.get('/cbstudio/api/me')).resolves.toEqual({ name: 'Ada' })

    expect(headersOf(fetchFn).get('Authorization')).toBe('Bearer access-1')
    expect(headersOf(fetchFn).get('x-refresh-token')).toBe('refresh-1')
  })

  it('keeps tokens refreshed by the server for the next request', async () => {
    const fetchFn = mockFetch(ok({}, { 'x-auth-token': 'access-2', 'x-refresh-token': 'refresh-2' }), ok())
    const api = new ApiClient(tokens, fetchFn)

    await api.get('/first')
    await api.get('/second')

    expect(headersOf(fetchFn, 1).get('Authorization')).toBe('Bearer access-2')
    expect(headersOf(fetchFn, 1).get('x-refresh-token')).toBe('refresh-2')
  })

  it('throws an ApiError with the server messages', async () => {
    const fetchFn = mockFetch(
      jsonResponse({ data: {}, error: true, messages: ['Invalid or Missing Authentication Credentials'] }, 401),
    )
    const api = new ApiClient(tokens, fetchFn)

    const error = await api.get('/cbstudio/api/me').catch((e: unknown) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({ status: 401, message: 'Invalid or Missing Authentication Credentials' })
  })

  it('sends a JSON body on POST', async () => {
    const fetchFn = mockFetch(ok(null))
    const api = new ApiClient(tokens, fetchFn)

    await api.post('/thing', { a: 1 })

    expect(initOf(fetchFn).method).toBe('POST')
    expect(initOf(fetchFn).body).toBe('{"a":1}')
    expect(headersOf(fetchFn).get('Content-Type')).toBe('application/json')
  })
})
