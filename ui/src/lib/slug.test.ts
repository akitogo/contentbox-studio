import { describe, expect, it } from 'vitest'
import { slugify } from './slug'

describe('slugify', () => {
  it('makes an address segment from a title', () => {
    expect(slugify('Zimmer & Suiten in Göhren!')).toBe('zimmer-suiten-in-gohren')
    expect(slugify('  --  ')).toBe('')
  })
})
