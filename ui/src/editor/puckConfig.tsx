/**
 * Puck configuration from the site's block types (GET /blocks): one Puck component per block type
 */
import { FieldLabel, type ComponentConfig, type Config, type Field } from '@puckeditor/core'
import type { ComponentType } from 'react'
import type { BlockDefinition, ContentDetails, FieldDefinition } from '../types'
import { fieldLabel, isFieldVisible, itemSummary, withDefaults } from './blocksData'
import { BlockPreview } from './BlockPreview'
import { ContentStoreField, HtmlField, ImageField, ImagesField, LinkField } from './fields/Fields'
import { RichTextField } from './fields/RichTextField'

const CATEGORY_TITLES: Record<string, string> = {
  text: 'Text',
  media: 'Media',
  sections: 'Sections',
  advanced: 'Advanced',
  other: 'Other',
}

/**
 * @rootLabel   What the content is ("Page", "Blog entry"): Puck's title for it in the fields panel and breadcrumbs
 * @contentType Block types are offered only for the content types of their block.json; existing blocks of other
 *              types still show and can be edited
 */
export function buildConfig(
  definitions: BlockDefinition[],
  canEditHtml: boolean,
  rootLabel = 'Page',
  contentType: ContentDetails['contentType'] = 'page',
  /** Shown above the blocks in the canvas, e.g. a blog entry's header (CanvasHeader) */
  Header?: ComponentType,
): Config {
  const components: Record<string, ComponentConfig> = {}
  const categories: Record<string, { title: string; components: string[]; visible?: boolean }> = {}

  for (const definition of definitions) {
    const fields = Object.fromEntries(definition.fields.map((field) => [field.name, toPuckField(field)]))
    const conditional = definition.fields.some((field) => field.when)
    components[definition.name] = {
      label: definition.label,
      fields,
      // Fields with `when` show only for matching values of other fields
      ...(conditional
        ? {
            resolveFields: (data: { props: Record<string, unknown> }) =>
              Object.fromEntries(definition.fields.filter((field) => isFieldVisible(field, data.props)).map((field) => [field.name, fields[field.name]])),
          }
        : {}),
      defaultProps: withDefaults(definition.fields),
      render: ({ puck: _puck, editMode: _editMode, id, ...data }: Record<string, unknown>) => (
        <BlockPreview type={definition.name} label={definition.label} id={String(id ?? '')} data={data} />
      ),
    }
    // Not offered (existing ones still load): HTML blocks without STUDIO_HTML_BLOCKS, types for other content
    const offered = (definition.name !== 'html' || canEditHtml) && (definition.contentTypes ?? []).includes(contentType)
    const category = offered ? definition.category || 'other' : 'restricted'
    categories[category] ??= {
      title: CATEGORY_TITLES[category] ?? category.charAt(0).toUpperCase() + category.slice(1),
      components: [],
      ...(category === 'restricted' ? { visible: false } : {}),
    }
    categories[category].components.push(definition.name)
  }

  return {
    components,
    categories,
    // No root fields: page settings (title, slug, SEO) stay in ContentBox
    // Inline style: the canvas only has the theme's CSS
    root: {
      label: rootLabel,
      fields: {},
      render: ({ children }: { children?: React.ReactNode }) => (
        <div style={{ padding: 24 }}>
          {Header && <Header />}
          {children}
        </div>
      ),
    },
  } as Config
}

/** The Puck field for a block type field */
export function toPuckField(field: FieldDefinition): Field {
  const label = fieldLabel(field)
  const custom = (
    render: (props: { value: unknown; onChange: (value: unknown) => void; readOnly?: boolean }) => React.ReactElement,
    contentEditable = false,
  ): Field => ({
    type: 'custom',
    label,
    // Puck intercepts key presses in fields unless they say they are content-editable (TipTap is)
    contentEditable,
    render: ({ value, onChange, readOnly }) => (
      // A div, not a label: a click inside a <label> also clicks its first button (e.g. Bold in the text toolbar)
      <FieldLabel label={label} el="div">
        {render({ value, onChange, readOnly })}
        {field.help && <p className="mt-1.5 text-xs text-slate-500">{field.help}</p>}
      </FieldLabel>
    ),
  })

  switch (field.type) {
    case 'text':
      return { type: 'text', label }
    case 'textarea':
      return { type: 'textarea', label }
    case 'number':
      return { type: 'number', label, min: field.min, max: field.max }
    case 'boolean':
      return { type: 'radio', label, options: [{ label: 'Yes', value: true }, { label: 'No', value: false }] }
    case 'select':
      return { type: 'select', label, options: field.options ?? [] }
    case 'richtext':
      return custom(({ value, onChange, readOnly }) => <RichTextField value={value} onChange={onChange} readOnly={readOnly} />, true)
    case 'link':
      return custom(({ value, onChange, readOnly }) => <LinkField value={value} onChange={onChange} readOnly={readOnly} />)
    case 'image':
      return custom(({ value, onChange, readOnly }) => <ImageField value={value} onChange={onChange} readOnly={readOnly} />)
    case 'images':
      return custom(({ value, onChange, readOnly }) => <ImagesField value={value} onChange={onChange} readOnly={readOnly} />)
    case 'html':
      return custom(({ value, onChange }) => <HtmlField value={value} onChange={onChange} />)
    case 'contentStore':
      return custom(({ value, onChange, readOnly }) => <ContentStoreField value={value} onChange={onChange} readOnly={readOnly} />)
    case 'list': {
      const subFields = field.fields ?? []
      return {
        type: 'array',
        label,
        arrayFields: Object.fromEntries(subFields.map((sub) => [sub.name, toPuckField(sub)])),
        defaultItemProps: withDefaults(subFields),
        getItemSummary: (item: Record<string, unknown>, index?: number) => itemSummary(subFields, item, index ?? 0),
        ...(field.maxItems ? { max: field.maxItems } : {}),
      } as Field
    }
  }
}
