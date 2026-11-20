import { describe, expect, it } from 'vitest'
import type { BlockDefinition } from '../types'
import { buildConfig } from './puckConfig'

const definition = (name: string, contentTypes: BlockDefinition['contentTypes']): BlockDefinition => ({
  name,
  label: name,
  description: '',
  icon: 'block',
  category: 'sections',
  version: 1,
  source: 'theme',
  fields: [],
  contentTypes,
})

const definitions = [definition('hero', ['page']), definition('text', ['page', 'entry', 'contentStore']), definition('html', ['page', 'entry', 'contentStore'])]

/** Block types the blocks list offers (categories that are not hidden) */
const offered = (config: ReturnType<typeof buildConfig>) =>
  Object.values(config.categories ?? {})
    .filter((category) => category.visible !== false)
    .flatMap((category) => category.components ?? [])

describe('buildConfig', () => {
  it('offers block types only for their content types, but still knows the others', () => {
    const forEntry = buildConfig(definitions, true, 'Blog entry', 'entry')
    expect(offered(forEntry)).toEqual(['text', 'html'])
    expect(Object.keys(forEntry.components)).toEqual(['hero', 'text', 'html'])
    expect(offered(buildConfig(definitions, true, 'Page', 'page'))).toEqual(['hero', 'text', 'html'])
  })

  it('offers HTML blocks only with STUDIO_HTML_BLOCKS', () => {
    expect(offered(buildConfig(definitions, false, 'Page', 'page'))).toEqual(['hero', 'text'])
  })

  it('labels the content', () => {
    expect(buildConfig(definitions, true, 'Blog entry', 'entry').root?.label).toBe('Blog entry')
  })
})
