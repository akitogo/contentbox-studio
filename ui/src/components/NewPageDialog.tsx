import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router'
import { buildTree, type TreeNode } from '../lib/tree'
import { slugify } from '../lib/slug'
import { messageOf, useStudio } from '../studio'
import type { Site, TemplateInfo, TreePage } from '../types'
import { Alert, Button, Dialog, Field, Input, Select } from '../ui'

/**
 * Create a draft page (optionally from a content template, i.e. a block preset) and open it in the editor
 */
export function NewPageDialog({
  site,
  pages,
  parentID: initialParent = '',
  onClose,
}: {
  site: Site
  pages: TreePage[]
  parentID?: string
  onClose: () => void
}) {
  const { config, api } = useStudio()
  const navigate = useNavigate()
  const [title, setTitle] = useState('')
  const [slug, setSlug] = useState('')
  const [parentID, setParentID] = useState(initialParent)
  const [templateID, setTemplateID] = useState('')
  const [templates, setTemplates] = useState<TemplateInfo[]>([])
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    api
      .get<TemplateInfo[]>(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/templates?contentType=page`)
      .then(setTemplates, () => setTemplates([]))
  }, [api, config, site])

  const parentOptions = useMemo(() => {
    const options: { id: string; label: string }[] = []
    const walk = (nodes: TreeNode[]) =>
      nodes.forEach((node) => {
        options.push({ id: node.page.contentID, label: `${' '.repeat(node.depth)}${node.page.title}` })
        walk(node.children)
      })
    walk(buildTree(pages))
    return options
  }, [pages])

  const parent = pages.find((page) => page.contentID === parentID)
  const segment = slugify(slug || title)
  const address = `/${parent ? `${parent.slug}/` : ''}${segment}`

  async function create(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    try {
      const created = await api.post<{ contentID: string }>(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/pages`, {
        title,
        slug,
        parentID,
        templateID,
      })
      navigate(`/content/${created.contentID}`)
    } catch (e) {
      setError(messageOf(e))
      setSaving(false)
    }
  }

  return (
    <Dialog
      title="New page"
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" type="submit" form="cbstudio-new-page" disabled={!title.trim() || saving}>
            {saving ? 'Creating…' : 'Create and edit'}
          </Button>
        </>
      }
    >
      <form id="cbstudio-new-page" onSubmit={create} className="grid gap-4">
        <Field label="Title" htmlFor="new-page-title">
          <Input id="new-page-title" value={title} onChange={(event) => setTitle(event.target.value)} required />
        </Field>
        <Field label="Address" htmlFor="new-page-slug" help={`The page will be at ${address}`}>
          <Input id="new-page-slug" value={slug} onChange={(event) => setSlug(event.target.value)} placeholder={slugify(title) || 'from the title'} />
        </Field>
        <Field label="Parent page" htmlFor="new-page-parent">
          <Select id="new-page-parent" value={parentID} onChange={(event) => setParentID(event.target.value)}>
            <option value="">None (top level)</option>
            {parentOptions.map((option) => (
              <option key={option.id} value={option.id}>
                {option.label}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Start from" htmlFor="new-page-template" help="Templates are ContentBox content templates; their blocks become the start of the page.">
          <Select id="new-page-template" value={templateID} onChange={(event) => setTemplateID(event.target.value)}>
            <option value="">An empty page</option>
            {templates.map((template) => (
              <option key={template.templateID} value={template.templateID}>
                {template.name}
                {template.hasBlocks ? '' : ' (HTML)'}
              </option>
            ))}
          </Select>
        </Field>
        <p className="text-xs text-slate-500">New pages start as drafts: publish them from the editor when they are ready.</p>
        {error && <Alert tone="danger">{error}</Alert>}
      </form>
    </Dialog>
  )
}
