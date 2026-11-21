import { describe, expect, it } from 'vitest'
import { moveMessage } from './SiteTreePane'

describe('moveMessage', () => {
  it('mentions the redirect only when the address changed', () => {
    expect(moveMessage({ slug: 'about/team', previousSlug: 'team' })).toBe('Moved to /about/team. The old address redirects there.')
    expect(moveMessage({ slug: 'home', previousSlug: 'home' })).toBe('Order saved.')
  })
})
