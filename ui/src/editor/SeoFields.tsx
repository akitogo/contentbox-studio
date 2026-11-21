import { ChevronDown, ChevronRight } from 'lucide-react'
import { useId, useState, type ChangeEvent } from 'react'
import { store, stored } from '../lib/storage'
import { readableURL } from '../lib/url'
import type { Seo } from '../types'
import { cx, Field, Input, Textarea } from '../ui'

/** What ContentBox stores at most, and about what search engines show of title and description */
const LIMITS = { title: { max: 255, shown: 60 }, description: { max: 160, shown: 160 }, keywords: { max: 160 } }

/** Whether the search result preview is collapsed, remembered for all content */
const PREVIEW_KEY = 'cbstudio.seoPreviewHidden'

/** Text cut to a length with an ellipsis, as search engines show long titles */
const shorten = (text: string, length: number) => (text.length > length ? `${text.slice(0, length - 1).trimEnd()}…` : text)

/**
 * ContentBox's HTML title, meta description and keywords of a page or entry, with a preview of the search result.
 * Changes are saved with the editor's Save, like the blocks.
 */
export function SeoFields({
  seo,
  onChange,
  title,
  url,
  disabled,
}: {
  seo: Seo
  onChange: (seo: Seo) => void
  /** The content's title, used when the SEO title is empty */
  title: string
  url: string
  disabled: boolean
}) {
  const set = (key: keyof Seo) => (event: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => onChange({ ...seo, [key]: event.target.value })
  const shownTitle = seo.title.trim() || title
  const description = seo.description.trim()
  // Unique ids: Puck renders the fields twice (its narrow layout has its own, hidden copy)
  const uid = useId()
  const [previewHidden, setPreviewHidden] = useState(() => stored(PREVIEW_KEY) === '1')
  const shownURL = readableURL(url)

  function togglePreview() {
    setPreviewHidden(!previewHidden)
    store(PREVIEW_KEY, previewHidden ? '0' : '1')
  }

  return (
    <section className="grid gap-3" aria-labelledby={`${uid}-heading`}>
      <div className="flex items-baseline justify-between gap-2">
        <h3 id={`${uid}-heading`} className="text-xs font-medium tracking-wide text-slate-500 uppercase">
          Search engines
        </h3>
        <span className="text-xs text-slate-400">Saved with Save</span>
      </div>
      <Field
        label="Title"
        htmlFor={`${uid}-title`}
        help={<Length text={shownTitle} shown={LIMITS.title.shown} empty={seo.title.trim() ? '' : 'Empty: the title of the content is used.'} />}
      >
        <Input id={`${uid}-title`} value={seo.title} maxLength={LIMITS.title.max} placeholder={title} onChange={set('title')} disabled={disabled} />
      </Field>
      <Field label="Description" htmlFor={`${uid}-description`} help={<Length text={description} shown={LIMITS.description.shown} max />}>
        <Textarea
          id={`${uid}-description`}
          rows={4}
          value={seo.description}
          maxLength={LIMITS.description.max}
          placeholder="One or two sentences on what the page offers"
          onChange={set('description')}
          disabled={disabled}
        />
      </Field>
      <Field label="Keywords" htmlFor={`${uid}-keywords`} help="Separated by commas. Most search engines ignore them.">
        <Input id={`${uid}-keywords`} value={seo.keywords} maxLength={LIMITS.keywords.max} onChange={set('keywords')} disabled={disabled} />
      </Field>
      <div className="grid gap-1">
        <button
          type="button"
          aria-expanded={!previewHidden}
          aria-controls={`${uid}-preview`}
          onClick={togglePreview}
          className="-ml-0.5 flex cursor-pointer items-center gap-0.5 justify-self-start rounded text-xs text-slate-500 hover:text-slate-900 focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:outline-none"
        >
          {previewHidden ? <ChevronRight className="size-3.5" /> : <ChevronDown className="size-3.5" />}
          Preview in search results
        </button>
        <div id={`${uid}-preview`} hidden={previewHidden} className="grid gap-0.5 rounded-md border border-slate-200 bg-white p-3">
          <span className="truncate text-xs text-slate-500" title={shownURL}>
            {shownURL}
          </span>
          <span className="line-clamp-2 text-[15px] leading-snug text-[#1a0dab]">{shorten(shownTitle, LIMITS.title.shown)}</span>
          <span className={cx('line-clamp-3 text-xs leading-relaxed', description ? 'text-slate-600' : 'text-slate-400 italic')}>
            {description || 'No description: search engines take text from the page.'}
          </span>
        </div>
      </div>
    </section>
  )
}

/** "42 / 60 characters", amber once search engines would cut it off; `max`: the limit is also the most allowed */
function Length({ text, shown, max = false, empty = '' }: { text: string; shown: number; max?: boolean; empty?: string }) {
  const over = text.length > shown
  return (
    <>
      <span className={cx('tabular-nums', over && 'text-amber-700')}>
        {text.length} / {shown} characters
      </span>
      {over && !max && ' · longer ones are cut off in search results'}
      {empty && ` · ${empty}`}
    </>
  )
}
