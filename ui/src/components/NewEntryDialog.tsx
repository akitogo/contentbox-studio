import { useEffect, useState, type FormEvent } from 'react'
import { slugify } from '../lib/slug'
import { messageOf, useStudio } from '../studio'
import type { Site, TemplateInfo } from '../types'
import { Alert, Button, Dialog, Field, Input, Select } from '../ui'
import { useWorkspace } from '../workspace/WorkspaceContext'

/**
 * Create a draft blog entry (optionally from a content template for entries) and open it in the editor
 */
export function NewEntryDialog({ site, onClose }: { site: Site; onClose: () => void }) {
  const { config, api } = useStudio()
  const { reload, openPage } = useWorkspace()
  const [title, setTitle] = useState('')
  const [slug, setSlug] = useState('')
  const [templateID, setTemplateID] = useState('')
  const [templates, setTemplates] = useState<TemplateInfo[]>([])
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const base = `${config.studioApi}/sites/${encodeURIComponent(site.siteID)}`

  useEffect(() => {
    api.get<TemplateInfo[]>(`${base}/templates?contentType=entry`).then(setTemplates, () => setTemplates([]))
  }, [api, base])

  async function create(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    try {
      const created = await api.post<{ contentID: string }>(`${base}/entries`, { title, slug, templateID })
      await reload()
      onClose()
      openPage(created.contentID)
    } catch (e) {
      setError(messageOf(e))
      setSaving(false)
    }
  }

  return (
    <Dialog
      title="New blog entry"
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" type="submit" form="cbstudio-new-entry" disabled={!title.trim() || saving}>
            {saving ? 'Creating…' : 'Create and edit'}
          </Button>
        </>
      }
    >
      <form id="cbstudio-new-entry" onSubmit={create} className="grid gap-4">
        <Field label="Title" htmlFor="new-entry-title">
          <Input id="new-entry-title" value={title} onChange={(event) => setTitle(event.target.value)} required />
        </Field>
        <Field label="Address" htmlFor="new-entry-slug" help={`Within the blog: …/${slugify(slug || title) || '…'}`}>
          <Input id="new-entry-slug" value={slug} onChange={(event) => setSlug(event.target.value)} placeholder={slugify(title) || 'from the title'} />
        </Field>
        <Field label="Start from" htmlFor="new-entry-template" help="Templates are ContentBox content templates for entries; their blocks become the start of the entry.">
          <Select id="new-entry-template" value={templateID} onChange={(event) => setTemplateID(event.target.value)}>
            <option value="">An empty entry</option>
            {templates.map((template) => (
              <option key={template.templateID} value={template.templateID}>
                {template.name}
                {template.hasBlocks ? '' : ' (HTML)'}
              </option>
            ))}
          </Select>
        </Field>
        <p className="text-xs text-slate-500">New entries start as drafts: publish them from the editor when they are ready.</p>
        {error && <Alert tone="danger">{error}</Alert>}
      </form>
    </Dialog>
  )
}
