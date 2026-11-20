import { ImagePlus, X } from 'lucide-react'
import { useEffect, useId, useState, type KeyboardEvent } from 'react'
import { messageOf, useStudio } from '../studio'
import type { BlogCategory } from '../types'
import { Badge, Button, Checkbox, Field, Input } from '../ui'
import { withCategory, type CategoryChoice, type EntryEdit } from './contentSettings'
import { MediaPicker } from './fields/MediaPicker'
import { RichTextField } from './fields/RichTextField'

/**
 * A blog entry's own settings in the editor's right column: publish and unpublish date, categories, excerpt,
 * featured image and comments. Saved with Save, like the blocks.
 */
export function EntrySettingsFields({
  entry,
  onChange,
  siteID,
  disabled,
}: {
  entry: EntryEdit
  onChange: (entry: EntryEdit) => void
  siteID: string
  disabled: boolean
}) {
  const set = (change: Partial<EntryEdit>) => onChange({ ...entry, ...change })
  const [picking, setPicking] = useState(false)

  return (
    <section className="grid gap-3" aria-labelledby="entry-heading">
      <div className="flex items-baseline justify-between gap-2">
        <h3 id="entry-heading" className="text-xs font-medium tracking-wide text-slate-500 uppercase">
          Blog entry
        </h3>
        <span className="text-xs text-slate-400">Saved with Save</span>
      </div>

      <Field label="Publish on" htmlFor="entry-published" help="A later date schedules the entry: it appears then, once it is published.">
        <Input id="entry-published" type="datetime-local" value={entry.publishedDate} onChange={(event) => set({ publishedDate: event.target.value })} disabled={disabled} />
      </Field>
      <Field label="Unpublish on" htmlFor="entry-expires" help="Optional: the entry goes offline then.">
        <div className="flex gap-2">
          <Input id="entry-expires" type="datetime-local" value={entry.expireDate} onChange={(event) => set({ expireDate: event.target.value })} disabled={disabled} />
          {entry.expireDate && !disabled && (
            <Button variant="ghost" onClick={() => set({ expireDate: '' })}>
              Clear
            </Button>
          )}
        </div>
      </Field>

      <Field label="Categories" htmlFor="entry-category">
        <CategoryPicker id="entry-category" value={entry.categories} onChange={(categories) => set({ categories })} siteID={siteID} disabled={disabled} />
      </Field>

      <Field label="Excerpt" help="A short summary for blog lists and feeds, where the theme shows one.">
        <RichTextField value={entry.excerpt} onChange={(excerpt) => set({ excerpt })} readOnly={disabled} />
      </Field>

      <Field label="Featured image">
        <div className="grid gap-2">
          {entry.featuredImageURL ? (
            <button
              type="button"
              disabled={disabled}
              onClick={() => setPicking(true)}
              className="cursor-pointer overflow-hidden rounded-md border border-slate-200 bg-slate-100 hover:border-primary-400"
              title="Change image"
            >
              <img src={entry.featuredImageURL} alt="" className="max-h-40 w-full object-contain" />
            </button>
          ) : (
            <Button disabled={disabled} onClick={() => setPicking(true)} className="h-20 border-dashed">
              <ImagePlus className="size-4" />
              Choose image…
            </Button>
          )}
          {entry.featuredImage && !disabled && (
            <Button variant="ghost" size="sm" className="justify-self-start" onClick={() => set({ featuredImage: '', featuredImageURL: '' })}>
              Remove image
            </Button>
          )}
        </div>
      </Field>
      {picking && (
        <MediaPicker
          onClose={() => setPicking(false)}
          onSelect={(file) => {
            set({ featuredImage: file.url, featuredImageURL: file.url })
            setPicking(false)
          }}
        />
      )}

      <Checkbox label="Allow comments" checked={entry.allowComments} onChange={(event) => set({ allowComments: event.target.checked })} disabled={disabled} />
    </section>
  )
}

/** The chosen categories as chips; add one by name (an existing one is suggested, a new one is created on save) */
function CategoryPicker({
  id,
  value,
  onChange,
  siteID,
  disabled,
}: {
  id: string
  value: CategoryChoice[]
  onChange: (value: CategoryChoice[]) => void
  siteID: string
  disabled: boolean
}) {
  const { config, api } = useStudio()
  const [existing, setExisting] = useState<BlogCategory[]>([])
  const [name, setName] = useState('')
  const [error, setError] = useState('')
  const listID = useId()

  useEffect(() => {
    api.get<BlogCategory[]>(`${config.studioApi}/sites/${encodeURIComponent(siteID)}/categories`).then(setExisting, (e: unknown) => setError(messageOf(e)))
  }, [api, config, siteID])

  function add() {
    onChange(withCategory(value, name, existing))
    setName('')
  }

  function onKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key !== 'Enter') return
    event.preventDefault()
    add()
  }

  const chosen = new Set(value.map((category) => category.categoryID).filter(Boolean))

  return (
    <div className="grid gap-2">
      {value.length > 0 ? (
        <ul className="flex flex-wrap gap-1.5" aria-label="Chosen categories">
          {value.map((category) => (
            <li key={category.categoryID || `new:${category.name}`}>
              <Badge tone={category.categoryID ? 'primary' : 'info'} className="gap-1">
                {category.name}
                {!category.categoryID && <span className="font-normal opacity-70">(new)</span>}
                {!disabled && (
                  <button
                    type="button"
                    aria-label={`Remove the category ${category.name}`}
                    className="-mr-1 cursor-pointer rounded-full opacity-60 hover:opacity-100"
                    onClick={() => onChange(value.filter((item) => item !== category))}
                  >
                    <X className="size-3" />
                  </button>
                )}
              </Badge>
            </li>
          ))}
        </ul>
      ) : (
        <p className="text-xs text-slate-500">No category.</p>
      )}
      {!disabled && (
        <div className="flex gap-2">
          <Input id={id} list={listID} value={name} onChange={(event) => setName(event.target.value)} onKeyDown={onKeyDown} placeholder="Add a category" />
          <datalist id={listID}>
            {existing
              .filter((category) => !chosen.has(category.categoryID))
              .map((category) => (
                <option key={category.categoryID} value={category.name} />
              ))}
          </datalist>
          <Button onClick={add} disabled={!name.trim()}>
            Add
          </Button>
        </div>
      )}
      {error && <p className="text-xs text-red-600">Could not load the categories: {error}</p>}
    </div>
  )
}
