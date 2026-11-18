/**
 * Custom Puck fields for Studio's field types: link, image, images, HTML and content store item
 */
import { ArrowDown, ArrowUp, ImagePlus, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { Button, Checkbox, IconButton, Input, Select, Textarea } from '../../ui'
import { useEditorContext } from '../EditorContext'
import { MediaPicker } from './MediaPicker'

export interface LinkValue {
  href: string
  target: string
}

export interface ImageValue {
  src: string
  alt: string
  width?: number
  height?: number
}

const asLink = (value: unknown): LinkValue => ({
  href: typeof (value as LinkValue)?.href === 'string' ? (value as LinkValue).href : '',
  target: (value as LinkValue)?.target === '_blank' ? '_blank' : '',
})

const asImage = (value: unknown): ImageValue => ({
  src: typeof (value as ImageValue)?.src === 'string' ? (value as ImageValue).src : '',
  alt: typeof (value as ImageValue)?.alt === 'string' ? (value as ImageValue).alt : '',
})

/** URL, a page of the site (ContentBox link syntax page:[slug]) and "new window" */
export function LinkField({ value, onChange, readOnly }: { value: unknown; onChange: (value: LinkValue) => void; readOnly?: boolean }) {
  const { pages } = useEditorContext()
  const link = asLink(value)
  const pageSlug = /^page:\[(.*)\]$/.exec(link.href)?.[1] ?? ''
  return (
    <div className="grid gap-2">
      <Select
        value={pageSlug}
        onChange={(event) => onChange({ ...link, href: event.target.value ? `page:[${event.target.value}]` : '' })}
        disabled={readOnly}
        aria-label="Link to a page of this site"
      >
        <option value="">Page of this site…</option>
        {[...pages]
          .sort((a, b) => a.slug.localeCompare(b.slug))
          .map((page) => (
            <option key={page.contentID} value={page.slug}>
              /{page.slug}
            </option>
          ))}
      </Select>
      <Input
        value={link.href}
        onChange={(event) => onChange({ ...link, href: event.target.value })}
        placeholder="or https://…, mailto:…"
        aria-label="Link address"
        readOnly={readOnly}
      />
      <Checkbox
        label="Open in a new window"
        checked={link.target === '_blank'}
        onChange={(event) => onChange({ ...link, target: event.target.checked ? '_blank' : '' })}
        disabled={readOnly}
      />
    </div>
  )
}

/** One image from the media library (or a URL) with its alt text */
export function ImageField({ value, onChange, readOnly }: { value: unknown; onChange: (value: ImageValue) => void; readOnly?: boolean }) {
  const [picking, setPicking] = useState(false)
  const image = asImage(value)
  return (
    <div className="grid gap-2">
      {image.src ? (
        <button
          type="button"
          disabled={readOnly}
          onClick={() => setPicking(true)}
          className="cursor-pointer overflow-hidden rounded-md border border-slate-200 bg-slate-100 hover:border-primary-400"
          title="Change image"
        >
          <img src={image.src} alt="" className="max-h-40 w-full object-contain" />
        </button>
      ) : (
        <Button disabled={readOnly} onClick={() => setPicking(true)} className="h-20 border-dashed">
          <ImagePlus className="size-4" />
          Choose image…
        </Button>
      )}
      <Input value={image.src} onChange={(event) => onChange({ ...image, src: event.target.value })} placeholder="/__media/… or https://…" aria-label="Image address" readOnly={readOnly} />
      <Input value={image.alt} onChange={(event) => onChange({ ...image, alt: event.target.value })} placeholder="Alternative text: what the image shows" aria-label="Alternative text" readOnly={readOnly} />
      {picking && (
        <MediaPicker
          onClose={() => setPicking(false)}
          onSelect={(file) => {
            onChange({ ...image, src: file.url })
            setPicking(false)
          }}
        />
      )}
    </div>
  )
}

/** Several images, e.g. for a gallery */
export function ImagesField({ value, onChange, readOnly }: { value: unknown; onChange: (value: ImageValue[]) => void; readOnly?: boolean }) {
  const [picking, setPicking] = useState(false)
  const images = Array.isArray(value) ? value.map(asImage) : []
  const update = (index: number, image: ImageValue) => onChange(images.map((item, i) => (i === index ? image : item)))
  const move = (index: number, by: number) => {
    const next = [...images]
    const [item] = next.splice(index, 1)
    if (item) next.splice(index + by, 0, item)
    onChange(next)
  }
  return (
    <div className="grid gap-2">
      {images.length > 0 && (
        <ol className="grid gap-2">
          {images.map((image, index) => (
            <li key={`${image.src}-${index}`} className="flex gap-2 rounded-md border border-slate-200 bg-white p-1.5">
              <img src={image.src} alt="" className="size-14 shrink-0 rounded object-cover" />
              <div className="grid min-w-0 flex-1 gap-1">
                <Input className="h-7 text-xs" value={image.alt} onChange={(event) => update(index, { ...image, alt: event.target.value })} placeholder="Alternative text" aria-label={`Alternative text of image ${index + 1}`} readOnly={readOnly} />
                {!readOnly && (
                  <div className="flex gap-0.5">
                    <IconButton label="Move up" disabled={index === 0} onClick={() => move(index, -1)}>
                      <ArrowUp className="size-3.5" />
                    </IconButton>
                    <IconButton label="Move down" disabled={index === images.length - 1} onClick={() => move(index, 1)}>
                      <ArrowDown className="size-3.5" />
                    </IconButton>
                    <IconButton label="Remove" onClick={() => onChange(images.filter((_, i) => i !== index))}>
                      <Trash2 className="size-3.5" />
                    </IconButton>
                  </div>
                )}
              </div>
            </li>
          ))}
        </ol>
      )}
      {!readOnly && (
        <Button onClick={() => setPicking(true)}>
          <ImagePlus className="size-4" />
          Add image…
        </Button>
      )}
      {picking && (
        <MediaPicker
          onClose={() => setPicking(false)}
          onSelect={(file) => {
            onChange([...images, { src: file.url, alt: '' }])
            setPicking(false)
          }}
        />
      )}
    </div>
  )
}

/** Raw HTML; read-only without STUDIO_HTML_BLOCKS */
export function HtmlField({ value, onChange }: { value: unknown; onChange: (value: string) => void }) {
  const { canEditHtml } = useEditorContext()
  return (
    <div className="grid gap-1.5">
      <Textarea
        className="font-mono text-xs"
        rows={14}
        value={typeof value === 'string' ? value : ''}
        onChange={(event) => onChange(event.target.value)}
        readOnly={!canEditHtml}
        spellCheck={false}
        aria-label="HTML"
      />
      {!canEditHtml && <p className="text-xs text-slate-500">Changing HTML needs the STUDIO_HTML_BLOCKS permission. You can move or remove this block.</p>}
    </div>
  )
}

/** A content store item of the site */
export function ContentStoreField({ value, onChange, readOnly }: { value: unknown; onChange: (value: string) => void; readOnly?: boolean }) {
  const { contentStoreItems } = useEditorContext()
  return (
    <Select value={typeof value === 'string' ? value : ''} onChange={(event) => onChange(event.target.value)} disabled={readOnly} aria-label="Content store item">
      <option value="">Choose an item…</option>
      {contentStoreItems.map((item) => (
        <option key={item.slug} value={item.slug}>
          {item.title} ({item.slug})
        </option>
      ))}
    </Select>
  )
}
