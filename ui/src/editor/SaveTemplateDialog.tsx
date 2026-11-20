import { useState, type FormEvent } from 'react'
import { messageOf, useStudio } from '../studio'
import type { ContentDetails } from '../types'
import { TEMPLATE_TARGETS } from './contentLabels'
import { Alert, Button, Checkbox, Dialog, Field, Input, Textarea } from '../ui'

/**
 * Store the saved blocks of the content as a ContentBox content template (block preset for new content of its type),
 * optionally as the default one (ContentBox's global template)
 */
export function SaveTemplateDialog({
  contentID,
  title,
  contentType,
  dirty,
  onSaved,
  onClose,
}: {
  contentID: string
  title: string
  contentType: ContentDetails['contentType']
  dirty: boolean
  onSaved: (name: string, isGlobal: boolean) => void
  onClose: () => void
}) {
  const { config, api } = useStudio()
  const [name, setName] = useState(title)
  const [description, setDescription] = useState('')
  const [isGlobal, setIsGlobal] = useState(false)
  const what = TEMPLATE_TARGETS[contentType]
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  async function save(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    try {
      const saved = await api.post<{ name: string }>(`${config.studioApi}/content/${contentID}/template`, { name, description, isGlobal })
      onSaved(saved.name, isGlobal)
    } catch (e) {
      setError(messageOf(e))
      setSaving(false)
    }
  }

  return (
    <Dialog
      title="Save as template"
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" type="submit" form="cbstudio-template" disabled={!name.trim() || saving}>
            {saving ? 'Saving…' : 'Save template'}
          </Button>
        </>
      }
    >
      <form id="cbstudio-template" onSubmit={save} className="grid gap-4">
        <p className="text-sm text-slate-600">
          New {what} can start from this template: its blocks become their start. Templates are ContentBox content templates, so they are also listed in the classic admin.
        </p>
        {dirty && <Alert tone="warning">The template uses the last saved version. Save your changes first to include them.</Alert>}
        <Field label="Name" htmlFor="template-name">
          <Input id="template-name" value={name} onChange={(event) => setName(event.target.value)} required />
        </Field>
        <Field label="Description" htmlFor="template-description">
          <Textarea id="template-description" rows={3} value={description} onChange={(event) => setDescription(event.target.value)} />
        </Field>
        <Checkbox label={`Default for new ${what} (replaces the current default)`} checked={isGlobal} onChange={(event) => setIsGlobal(event.target.checked)} />
        {error && <Alert tone="danger">{error}</Alert>}
      </form>
    </Dialog>
  )
}
