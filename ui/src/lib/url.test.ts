import { describe, expect, it } from 'vitest'
import { urlPath } from './url'

describe('urlPath', () => {
  it('drops protocol and domain', () => {
    expect(urlPath('http://127.0.0.1:8589/blog/autumn-offer')).toBe('/blog/autumn-offer')
    expect(urlPath('https://example.com/en/research?x=1#top')).toBe('/en/research?x=1#top')
  })

  it('shows encoded characters readably', () => {
    expect(urlPath('https://example.com/de/%C3%BCber-uns')).toBe('/de/über-uns')
    expect(urlPath('https://example.com/de/%E0%A4%A')).toBe('/de/%E0%A4%A')
  })

  it('keeps what is not a full URL', () => {
    expect(urlPath('/blog/post')).toBe('/blog/post')
    expect(urlPath('')).toBe('')
  })
})
