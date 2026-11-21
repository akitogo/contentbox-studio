import { describe, expect, it } from 'vitest'
import { readableURL, urlPath } from './url'

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

describe('readableURL', () => {
  it('keeps protocol and domain and decodes the rest', () => {
    expect(readableURL('https://example.com/de/%C3%BCber-uns')).toBe('https://example.com/de/über-uns')
    expect(readableURL('http://127.0.0.1:8589/de')).toBe('http://127.0.0.1:8589/de')
  })

  it('keeps what cannot be decoded', () => {
    expect(readableURL('https://example.com/%E0%A4%A')).toBe('https://example.com/%E0%A4%A')
  })
})
