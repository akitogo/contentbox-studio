import { describe, expect, it } from 'vitest'
import { withWidgetPlaceholders } from './BlockPreview'

describe('withWidgetPlaceholders', () => {
  it('replaces widget calls with placeholders and keeps the rest', () => {
    const html = withWidgetPlaceholders('<section>{{{~SiteHeader lang="de"}}}<h1>Hi</h1>{{{ContentStore slug="de-contact"}}}</section>')
    expect(html).toContain('Widget “SiteHeader”')
    expect(html).toContain('Content store item “de-contact”')
    expect(html).toContain('<h1>Hi</h1>')
    expect(html).not.toContain('{{{')
  })
})
