import { describe, expect, it } from 'vitest'
import { entriesQuery, NO_FILTER, shortDate } from './blog'

describe('entriesQuery', () => {
  it('sends only the filters that are set', () => {
    expect(entriesQuery(NO_FILTER, 50)).toBe('max=50')
    expect(entriesQuery({ search: '  summer ', status: 'draft', category: 'none' }, 100)).toBe('search=summer&status=draft&category=none&max=100')
  })

  it('encodes the search', () => {
    expect(entriesQuery({ ...NO_FILTER, search: 'a&b c' }, 50)).toBe('search=a%26b+c&max=50')
  })
})

describe('shortDate', () => {
  it('formats API dates and ignores missing or invalid ones', () => {
    expect(shortDate('2026-11-20T09:30:00', 'en-GB')).toBe('20 Nov 2026')
    expect(shortDate('', 'en-GB')).toBe('')
    expect(shortDate('nope', 'en-GB')).toBe('')
  })
})
