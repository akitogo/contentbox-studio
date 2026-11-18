import { useState, type FormEvent } from 'react'
import { messageOf, useStudio } from '../studio'
import { Alert, Button, Dialog, Field, Input, Textarea } from '../ui'

/**
 * Store the saved blocks of the content as a ContentBox content template (block preset for new pages)
 */
export function SaveTemplateDialog({
  contentID,
  title,
  dirty,
  onSaved,
  onClose,
}: {
  contentID: string
  title: string
  dirty: boolean
  onSaved: (name: string) => void
  onClose: () => void
}) {
  const { config, api } = useStudio()
  const [name, setName] = useState(title)
  const [description, setDescription] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  async function save(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError('')
    try {
      const saved = await api.post<{ name: string }>(`${config.studioApi}/content/${contentID}/template`, { name, description })
      onSaved(saved.name)
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
          New pages can start from this template: its blocks become the start of the page. Templates are ContentBox content templates, so they are also listed in the classic admin.
        </p>
        {dirty && <Alert tone="warning">The template uses the last saved version. Save your changes first to include them.</Alert>}
        <Field label="Name" htmlFor="template-name">
          <Input id="template-name" value={name} onChange={(event) => setName(event.target.value)} required />
        </Field>
        <Field label="Description" htmlFor="template-description">
          <Textarea id="template-description" rows={3} value={description} onChange={(event) => setDescription(event.target.value)} />
        </Field>
        {error && <Alert tone="danger">{error}</Alert>}
      </form>
    </Dialog>
  )
}
