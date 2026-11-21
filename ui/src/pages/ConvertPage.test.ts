import { describe, expect, it } from 'vitest'
import type { ConvertProfile } from '../types'
import { profileHelp } from './ConvertPage'

const profile = (change: Partial<ConvertProfile> = {}): ConvertProfile => ({
  name: 'p',
  label: 'P',
  theme: 'starter',
  compare: 'markup',
  prose: false,
  problems: [],
  ...change,
})

describe('profileHelp', () => {
  it('names the theme and the check', () => {
    expect(profileHelp(profile())).toBe('For the theme starter; same look: the markup must stay the same')
  })

  it('says when a profile is for any theme and converts plain text', () => {
    expect(profileHelp(profile({ theme: '*', compare: 'content', prose: true }))).toBe(
      "For any theme; new look: nothing may be lost; plain text becomes Studio's text, heading and image blocks",
    )
  })
})
