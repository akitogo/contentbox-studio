/**
 * Custom Puck fields for Studio's field types: link, image, images, HTML and content store item
 */
import { useState } from 'react'
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
    <div className="studio-field-stack">
      <select
        value={pageSlug}
        onChange={(event) => onChange({ ...link, href: event.target.value ? `page:[${event.target.value}]` : '' })}
        disabled={readOnly}
        aria-label="Link to a page of this site"
      >
        <option value="">Page of this site…</option>
        {[...pages]
          .sort((a, b) => a.slug.localeCompare(b.slug))
          .map((page) => (
            <option key={page.contentID} value={page.slug}>/{page.slug}</option>
          ))}
      </select>
      <input
        value={link.href}
        onChange={(event) => onChange({ ...link, href: event.target.value })}
        placeholder="or https://… / mailto:…"
        aria-label="Link address"
        readOnly={readOnly}
      />
      <label className="studio-checkbox">
        <input
          type="checkbox"
          checked={link.target === '_blank'}
          onChange={(event) => onChange({ ...link, target: event.target.checked ? '_blank' : '' })}
          disabled={readOnly}
        />
        Open in a new window
      </label>
    </div>
  )
}

/** One image from the media library (or a URL) with its alt text */
export function ImageField({ value, onChange, readOnly }: { value: unknown; onChange: (value: ImageValue) => void; readOnly?: boolean }) {
  const [picking, setPicking] = useState(false)
  const image = asImage(value)
  return (
    <div className="studio-field-stack">
      {image.src && <img className="studio-thumb" src={image.src} alt="" />}
      {!readOnly && (
        <button type="button" onClick={() => setPicking(true)}>
          {image.src ? 'Change image…' : 'Choose image…'}
        </button>
      )}
      <input value={image.src} onChange={(event) => onChange({ ...image, src: event.target.value })} placeholder="/__media/… or https://…" aria-label="Image address" readOnly={readOnly} />
      <input value={image.alt} onChange={(event) => onChange({ ...image, alt: event.target.value })} placeholder="Alternative text (what the image shows)" aria-label="Alternative text" readOnly={readOnly} />
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
    <div className="studio-field-stack">
      <ol className="studio-images">
        {images.map((image, index) => (
          <li key={`${image.src}-${index}`}>
            <img className="studio-thumb" src={image.src} alt="" />
            <input value={image.alt} onChange={(event) => update(index, { ...image, alt: event.target.value })} placeholder="Alternative text" aria-label={`Alternative text of image ${index + 1}`} readOnly={readOnly} />
            {!readOnly && (
              <span className="studio-images__actions">
                <button type="button" disabled={index === 0} onClick={() => move(index, -1)} aria-label="Move up">↑</button>
                <button type="button" disabled={index === images.length - 1} onClick={() => move(index, 1)} aria-label="Move down">↓</button>
                <button type="button" onClick={() => onChange(images.filter((_, i) => i !== index))} aria-label="Remove">×</button>
              </span>
            )}
          </li>
        ))}
      </ol>
      {!readOnly && <button type="button" onClick={() => setPicking(true)}>Add image…</button>}
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
    <div className="studio-field-stack">
      <textarea
        className="studio-code"
        rows={12}
        value={typeof value === 'string' ? value : ''}
        onChange={(event) => onChange(event.target.value)}
        readOnly={!canEditHtml}
        spellCheck={false}
        aria-label="HTML"
      />
      {!canEditHtml && <p className="studio-muted">Changing HTML needs the STUDIO_HTML_BLOCKS permission. You can move or remove this block.</p>}
    </div>
  )
}

/** A content store item of the site */
export function ContentStoreField({ value, onChange, readOnly }: { value: unknown; onChange: (value: string) => void; readOnly?: boolean }) {
  const { contentStoreItems } = useEditorContext()
  return (
    <select value={typeof value === 'string' ? value : ''} onChange={(event) => onChange(event.target.value)} disabled={readOnly} aria-label="Content store item">
      <option value="">Choose an item…</option>
      {contentStoreItems.map((item) => (
        <option key={item.slug} value={item.slug}>{item.title} ({item.slug})</option>
      ))}
    </select>
  )
}
