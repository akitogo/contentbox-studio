import { describe, expect, it } from 'vitest'
import { editedValue, widgetFlex, withWidgetPlaceholders } from './BlockPreview'

describe('withWidgetPlaceholders', () => {
  it('replaces widget calls with placeholders and keeps the rest', () => {
    const html = withWidgetPlaceholders('<section>{{{~SiteHeader lang="de"}}}<h1>Hi</h1>{{{ContentStore slug="de-contact"}}}</section>')
    expect(html).toContain('Widget “SiteHeader”')
    expect(html).toContain('Content store item “de-contact”')
    expect(html).toContain('<h1>Hi</h1>')
    expect(html).not.toContain('{{{')
    expect(html.match(/data-cbs-widget/g)).toHaveLength(2)
  })
})

describe('widgetFlex', () => {
  it('gives a placeholder its own row in a wrapping flex row', () => {
    expect(widgetFlex({ display: 'flex', flexDirection: 'row', flexWrap: 'wrap' })).toBe('0 0 100%')
    expect(widgetFlex({ display: 'inline-flex', flexDirection: 'row-reverse', flexWrap: 'wrap-reverse' })).toBe('0 0 100%')
  })

  it('keeps it compact elsewhere', () => {
    expect(widgetFlex({ display: 'flex', flexDirection: 'row', flexWrap: 'nowrap' })).toBeNull()
    expect(widgetFlex({ display: 'flex', flexDirection: 'column', flexWrap: 'wrap' })).toBeNull()
    expect(widgetFlex({ display: 'grid', flexDirection: 'row', flexWrap: 'nowrap' })).toBeNull()
    expect(widgetFlex({ display: 'block', flexDirection: 'row', flexWrap: 'nowrap' })).toBeNull()
  })
})

describe('editedValue', () => {
  it('keeps line breaks for multi-line fields and joins single-line ones', () => {
    expect(editedValue('Fresh ideas\nfor every season.\n', true)).toBe('Fresh ideas\nfor every season.')
    expect(editedValue('Two\nlines', false)).toBe('Two lines')
    expect(editedValue('Plain', false)).toBe('Plain')
  })
})
