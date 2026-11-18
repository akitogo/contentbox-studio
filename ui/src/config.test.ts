import { describe, expect, it } from 'vitest'
import { basePath, parseConfig } from './config'

const valid = {
  version: '0.1.0',
  appBase: 'http://example.test/cbstudio/',
  studioApi: 'http://example.test/cbstudio/api/',
  contentboxApi: 'http://example.test/cbapi/v1/',
  adminUrl: 'http://example.test/cbadmin',
  logoutUrl: 'http://example.test/cbadmin/security/doLogout',
  tokens: { access_token: 'access', refresh_token: 'refresh' },
}

describe('parseConfig', () => {
  it('strips trailing slashes from the API base URLs', () => {
    const config = parseConfig(JSON.stringify(valid))
    expect(config.studioApi).toBe('http://example.test/cbstudio/api')
    expect(config.contentboxApi).toBe('http://example.test/cbapi/v1')
  })

  it('rejects a config without tokens', () => {
    expect(() => parseConfig(JSON.stringify({ ...valid, tokens: {} }))).toThrow(/no tokens/)
  })
})

describe('basePath', () => {
  it('is the path of the app URL', () => {
    expect(basePath(parseConfig(JSON.stringify(valid)))).toBe('/cbstudio')
  })
})
