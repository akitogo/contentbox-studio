/**
 * The conversion tool (STUDIO_CONVERT): turn the HTML of a site's pages, entries and content store items into blocks
 * with a conversion profile. Copy the site first to convert it to a new look without touching the original.
 * Server side: models/convert/, docs/conversion.md.
 */
import { ChevronDown, ChevronRight, Copy, ExternalLink, Play, Trash2 } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router'
import { Header } from '../components/Header'
import { basePath } from '../config'
import { slugify } from '../lib/slug'
import { rememberedSite } from '../lib/start'
import { store, stored } from '../lib/storage'
import { messageOf, useStudio } from '../studio'
import type { ConvertIndex, ConvertItem, ConvertProfile, ConvertReport, ConvertResult, ConvertSection, CopyResult, Site } from '../types'
import { Alert, Badge, Button, Card, Checkbox, Dialog, Field, Input, Loading, Select, Spinner, cx } from '../ui'

const PROFILE_KEY = 'cbstudio.convert.profile'
const TYPE_LABELS: Record<ConvertItem['contentType'], string> = { Page: 'Page', Entry: 'Blog entry', ContentStore: 'Content store' }

export function ConvertPage() {
  const { config, api, me, sites } = useStudio()
  const [params, setParams] = useSearchParams()
  const site = sites.find((item) => item.slug === params.get('site')) ?? sites.find((item) => item.siteID === rememberedSite()) ?? sites[0]
  const [index, setIndex] = useState<ConvertIndex | null>(null)
  const [profile, setProfile] = useState(() => stored(PROFILE_KEY) ?? '')
  const [report, setReport] = useState<ConvertReport | null>(null)
  const [running, setRunning] = useState(false)
  const [error, setError] = useState('')
  const [selected, setSelected] = useState<string[]>([])
  const [expanded, setExpanded] = useState('')
  const [result, setResult] = useState<ConvertResult | null>(null)
  const [converting, setConverting] = useState(false)
  const [copying, setCopying] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const allowed = me.permissions.convert

  useEffect(() => {
    if (!allowed) return
    api
      .get<ConvertIndex>(`${config.studioApi}/convert`)
      .then(setIndex)
      .catch((reason) => setError(messageOf(reason)))
  }, [api, config, allowed])

  const profiles = index?.profiles ?? []
  const chosen = profiles.find((item) => item.name === profile)

  const run = useCallback(async () => {
    if (!site || !chosen) return
    setRunning(true)
    setError('')
    try {
      setReport(
        await api.get<ConvertReport>(
          `${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/convert?profile=${encodeURIComponent(chosen.name)}`,
        ),
      )
    } catch (reason) {
      setReport(null)
      setError(messageOf(reason))
    } finally {
      setRunning(false)
    }
  }, [api, config, site, chosen])

  // A new site or profile: a new dry run
  useEffect(() => {
    setReport(null)
    setSelected([])
    setExpanded('')
    setResult(null)
    void run()
  }, [run])

  async function convert() {
    if (!site || !chosen || !selected.length) return
    setConverting(true)
    setError('')
    try {
      const outcome = await api.post<ConvertResult>(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/convert`, {
        profile: chosen.name,
        contentIDs: selected,
      })
      setResult(outcome)
      setSelected([])
      setExpanded('')
      await run()
    } catch (reason) {
      setError(messageOf(reason))
    } finally {
      setConverting(false)
    }
  }

  const ready = report?.items.filter((item) => item.ready) ?? []
  const original = site?.copiedFrom ? sites.find((item) => item.siteID === site.copiedFrom) : undefined

  return (
    <div className="flex h-screen flex-col overflow-hidden">
      <Header>
        <span className="text-sm font-medium text-slate-900">Convert pages to blocks</span>
      </Header>
      <main className="min-h-0 flex-1 overflow-auto bg-slate-50">
        <div className="mx-auto grid max-w-6xl gap-4 px-4 py-6">
          {!allowed ? (
            <Alert tone="warning">Converting pages needs the STUDIO_CONVERT permission.</Alert>
          ) : (
            <>
              <Card className="grid gap-4 p-4">
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label="Site" htmlFor="convert-site">
                    <div className="flex gap-2">
                      <Select
                        id="convert-site"
                        value={site?.slug ?? ''}
                        onChange={(event) => setParams({ site: event.target.value })}
                      >
                        {sites.map((item) => (
                          <option key={item.siteID} value={item.slug}>
                            {item.name}
                          </option>
                        ))}
                      </Select>
                      {me.permissions.sitesAdmin && site && (
                        <Button onClick={() => setCopying(true)} className="shrink-0">
                          <Copy className="size-3.5" />
                          Copy site…
                        </Button>
                      )}
                    </div>
                  </Field>
                  <Field
                    label="Profile"
                    htmlFor="convert-profile"
                    help={chosen ? profileHelp(chosen) : 'Profiles are in modules_app/contentbox-custom/_convert/'}
                  >
                    <div className="flex gap-2">
                      <Select
                        id="convert-profile"
                        value={chosen?.name ?? ''}
                        onChange={(event) => {
                          setProfile(event.target.value)
                          store(PROFILE_KEY, event.target.value)
                        }}
                      >
                        <option value="">Choose a profile…</option>
                        {profiles.map((item) => (
                          <option key={item.name} value={item.name}>
                            {item.label}
                          </option>
                        ))}
                      </Select>
                      <Button onClick={() => void run()} disabled={!chosen || running} className="shrink-0">
                        {running ? <Spinner /> : <Play className="size-3.5" />}
                        Dry run
                      </Button>
                    </div>
                  </Field>
                </div>
                {site &&
                  (original || site.copiedFrom ? (
                    <Alert tone="success">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="flex-1">A copy of {original?.name ?? 'another site'}: converting changes only this copy.</span>
                        {me.permissions.sitesAdmin && (
                          <Button size="sm" variant="ghost" onClick={() => setDeleting(true)}>
                            <Trash2 className="size-3.5" />
                            Delete copy…
                          </Button>
                        )}
                      </div>
                    </Alert>
                  ) : (
                    <Alert tone="info">
                      An original site: converting changes its content (each item as a new version, so it can be restored). For a new
                      look, copy the site first.
                    </Alert>
                  ))}
              </Card>

              {error && (
                <Alert tone="danger" onClose={() => setError('')}>
                  {error}
                </Alert>
              )}
              {result && <ResultAlert result={result} onClose={() => setResult(null)} />}
              {report && report.problems.length > 0 && (
                <Alert tone="danger">
                  <p className="font-medium">The profile cannot be used on this site:</p>
                  <ul className="mt-1 list-disc pl-5">
                    {report.problems.map((problem) => (
                      <li key={problem}>{problem}</li>
                    ))}
                  </ul>
                </Alert>
              )}
              {report && !report.canApply && report.problems.length === 0 && (
                <Alert tone="warning">This profile changes the look, so it can only convert a copy of a site. Copy the site first.</Alert>
              )}

              {running && !report && <Loading>Dry run…</Loading>}
              {report && report.problems.length === 0 && site && (
                <Card>
                  <div className="flex flex-wrap items-center gap-3 border-b border-slate-200 px-4 py-3">
                    <div className="text-sm text-slate-600">
                      <span className="font-medium text-slate-900">
                        {report.totals.ready} of {report.totals.items}
                      </span>{' '}
                      ready · {report.totals.converted} of {report.totals.sections} sections become blocks
                    </div>
                    <div className="flex-1" />
                    {ready.length > 0 && report.canApply && (
                      <Checkbox
                        label="All ready"
                        checked={selected.length === ready.length}
                        onChange={(event) => setSelected(event.target.checked ? ready.map((item) => item.contentID) : [])}
                      />
                    )}
                    <Button variant="primary" onClick={() => void convert()} disabled={!selected.length || converting || !report.canApply}>
                      {converting && <Spinner className="text-white" />}
                      Convert {selected.length || ''}
                    </Button>
                  </div>
                  {report.items.length === 0 ? (
                    <p className="px-4 py-6 text-sm text-slate-500">This site has no content.</p>
                  ) : (
                    <ul className="divide-y divide-slate-100">
                      {report.items.map((item) => (
                        <ItemRow
                          key={item.contentID}
                          item={item}
                          site={site}
                          profile={report.profile.name}
                          selectable={item.ready && report.canApply}
                          selected={selected.includes(item.contentID)}
                          onSelect={(on) =>
                            setSelected((current) => (on ? [...current, item.contentID] : current.filter((id) => id !== item.contentID)))
                          }
                          expanded={expanded === item.contentID}
                          onToggle={() => setExpanded((current) => (current === item.contentID ? '' : item.contentID))}
                        />
                      ))}
                    </ul>
                  )}
                </Card>
              )}
            </>
          )}
        </div>
      </main>
      {deleting && site && (
        <DeleteCopyDialog
          site={site}
          original={original}
          onClose={() => setDeleting(false)}
          onDeleted={() => window.location.assign(`${basePath(config)}/convert?site=${encodeURIComponent(original?.slug ?? '')}`)}
        />
      )}
      {copying && site && index && (
        <CopyDialog
          site={site}
          themes={index.themes}
          suggestedTheme={chosen?.theme}
          onClose={() => setCopying(false)}
          onOpen={(slug) => window.location.assign(`${basePath(config)}/convert?site=${encodeURIComponent(slug)}`)}
        />
      )}
    </div>
  )
}

/** What a profile does, in one line */
export function profileHelp(profile: ConvertProfile): string {
  const theme = profile.theme === '*' ? 'For any theme' : `For the theme ${profile.theme}`
  const check = profile.compare === 'content' ? 'new look: nothing may be lost' : 'same look: the markup must stay the same'
  return `${theme}; ${check}${profile.prose ? '; plain text becomes Studio\'s text, heading and image blocks' : ''}`
}

function ResultAlert({ result, onClose }: { result: ConvertResult; onClose: () => void }) {
  return (
    <Alert tone={result.skipped.length ? 'warning' : 'success'} onClose={onClose}>
      {result.saved.length} converted{result.saved.length ? ' (each as a new version)' : ''}.
      {result.skipped.length > 0 && (
        <ul className="mt-1 list-disc pl-5">
          {result.skipped.map((item) => (
            <li key={item.contentID}>
              {item.slug || item.contentID}: {item.reason}
            </li>
          ))}
        </ul>
      )}
    </Alert>
  )
}

function ItemRow({
  item,
  site,
  profile,
  selectable,
  selected,
  onSelect,
  expanded,
  onToggle,
}: {
  item: ConvertItem
  site: Site
  profile: string
  selectable: boolean
  selected: boolean
  onSelect: (on: boolean) => void
  expanded: boolean
  onToggle: () => void
}) {
  const status = item.ready ? (
    <Badge tone="success">Ready</Badge>
  ) : item.reason === 'already has blocks' ? (
    <Badge>Has blocks</Badge>
  ) : (
    <Badge tone={item.sections.length ? 'warning' : 'neutral'}>{item.reason}</Badge>
  )
  return (
    <li>
      <div className="flex items-start gap-3 px-4 py-2.5">
        <input
          type="checkbox"
          className="mt-1 size-4 accent-primary-600 disabled:opacity-30"
          checked={selected}
          disabled={!selectable}
          onChange={(event) => onSelect(event.target.checked)}
          aria-label={`Select ${item.title}`}
        />
        <button
          type="button"
          onClick={onToggle}
          disabled={!item.sections.length}
          className="flex min-w-0 flex-1 cursor-pointer items-start gap-2 text-left disabled:cursor-default"
        >
          {item.sections.length > 0 ? (
            expanded ? (
              <ChevronDown className="mt-0.5 size-4 shrink-0 text-slate-400" />
            ) : (
              <ChevronRight className="mt-0.5 size-4 shrink-0 text-slate-400" />
            )
          ) : (
            <span className="size-4 shrink-0" />
          )}
          <span className="min-w-0 flex-1">
            <span className="block truncate text-sm font-medium text-slate-900">{item.title}</span>
            <span className="block truncate text-xs text-slate-500">
              {TYPE_LABELS[item.contentType]} · {item.slug}
            </span>
          </span>
          <span className="hidden max-w-[45%] flex-wrap justify-end gap-1 md:flex">
            {item.sections.map((section) => (
              <SectionChip key={section.id} section={section} />
            ))}
          </span>
        </button>
        <span className="shrink-0">{status}</span>
      </div>
      {expanded && <ItemDetails item={item} site={site} profile={profile} />}
    </li>
  )
}

function SectionChip({ section }: { section: ConvertSection }) {
  const tone = section.type === 'html' ? (section.note ? 'warning' : 'neutral') : section.same ? 'success' : 'danger'
  return (
    <Badge tone={tone} className="font-mono">
      {section.type}
    </Badge>
  )
}

/** One item's sections with their HTML: what each became and why it differs */
function ItemDetails({ item, site, profile }: { item: ConvertItem; site: Site; profile: string }) {
  const { config, api } = useStudio()
  const [details, setDetails] = useState<ConvertItem | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    api
      .get<ConvertReport>(
        `${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/convert?profile=${encodeURIComponent(profile)}&contentID=${encodeURIComponent(item.contentID)}`,
      )
      .then((report) => !cancelled && setDetails(report.items[0] ?? null))
      .catch((reason) => !cancelled && setError(messageOf(reason)))
    return () => {
      cancelled = true
    }
  }, [api, config, site, profile, item.contentID])

  return (
    <div className="border-t border-slate-100 bg-slate-50 px-4 py-3 pl-14">
      <div className="mb-2 flex items-center gap-3 text-xs">
        <Link to={`/content/${item.contentID}?site=${encodeURIComponent(site.slug)}`} className="inline-flex items-center gap-1">
          Open in the editor <ExternalLink className="size-3" />
        </Link>
      </div>
      {error && <Alert tone="danger">{error}</Alert>}
      {!details && !error && <Loading />}
      {details && (
        <ol className="grid gap-2">
          {details.sections.map((section, position) => (
            <SectionDetails key={section.id} section={section} position={position + 1} />
          ))}
        </ol>
      )}
    </div>
  )
}

function SectionDetails({ section, position }: { section: ConvertSection; position: number }) {
  const [showHtml, setShowHtml] = useState(false)
  const differs = !section.same
  return (
    <li className={cx('rounded-md border bg-white p-3', differs ? 'border-red-200' : 'border-slate-200')}>
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <span className="text-slate-400">{position}.</span>
        <SectionChip section={section} />
        <span className="text-slate-600">
          {section.type === 'html' ? 'stays HTML' : section.same ? 'passes' : 'differs'}
        </span>
        <span className="flex-1" />
        {section.source !== undefined && (
          <button type="button" className="cursor-pointer text-xs text-primary-700 hover:underline" onClick={() => setShowHtml((on) => !on)}>
            {showHtml ? 'Hide HTML' : 'Show HTML'}
          </button>
        )}
      </div>
      {section.note && <p className="mt-1 text-xs whitespace-pre-line text-amber-800">{section.note}</p>}
      {section.errors.length > 0 && (
        <ul className="mt-1 list-disc pl-5 text-xs text-red-700">
          {section.errors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      )}
      {section.missing.length > 0 && (
        <div className="mt-1 text-xs text-red-700">
          <p>Missing in the block:</p>
          <ul className="list-disc pl-5">
            {section.missing.map((message) => (
              <li key={message}>{message}</li>
            ))}
          </ul>
        </div>
      )}
      {section.canonical && (
        <div className="mt-2 grid gap-2 md:grid-cols-2">
          <Code title="Before (normalized)" text={section.canonical.source} />
          <Code title="Block (normalized)" text={section.canonical.rendered} />
        </div>
      )}
      {showHtml && (
        <div className="mt-2 grid gap-2 md:grid-cols-2">
          <Code title="Before" text={section.source ?? ''} />
          <Code title={section.type === 'html' ? 'Kept as HTML' : 'Block'} text={section.rendered ?? ''} />
        </div>
      )}
    </li>
  )
}

function Code({ title, text }: { title: string; text: string }) {
  return (
    <div className="min-w-0">
      <p className="mb-1 text-xs font-medium text-slate-500">{title}</p>
      <pre className="max-h-72 overflow-auto rounded bg-slate-900 p-2 text-[11px] leading-relaxed text-slate-100">{text}</pre>
    </div>
  )
}

/** Delete a copy made by the tool, with its content (the original stays as it is) */
function DeleteCopyDialog({ site, original, onClose, onDeleted }: { site: Site; original?: Site; onClose: () => void; onDeleted: () => void }) {
  const { config, api } = useStudio()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function remove() {
    setBusy(true)
    setError('')
    try {
      await api.delete(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/copy`)
      onDeleted()
    } catch (reason) {
      setError(messageOf(reason))
      setBusy(false)
    }
  }

  return (
    <Dialog
      title={`Delete ${site.name}?`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="danger" onClick={() => void remove()} disabled={busy}>
            {busy && <Spinner className="text-white" />}
            Delete copy
          </Button>
        </>
      }
    >
      <div className="grid gap-3 text-sm text-slate-700">
        <p>
          This deletes the site {site.name} with all its pages, blog entries, content store items, menus and versions. It cannot be undone.{' '}
          {original ? `${original.name} stays as it is.` : 'The site it was copied from stays as it is.'}
        </p>
        {error && <Alert tone="danger">{error}</Alert>}
      </div>
    </Dialog>
  )
}

/** A new site as a copy of this one, with another theme; the original is only read */
function CopyDialog({
  site,
  themes,
  suggestedTheme,
  onClose,
  onOpen,
}: {
  site: Site
  themes: ConvertIndex['themes']
  suggestedTheme?: string
  onClose: () => void
  onOpen: (slug: string) => void
}) {
  const { config, api } = useStudio()
  const [name, setName] = useState(`${site.name} (new)`)
  const [slug, setSlug] = useState(slugify(`${site.slug} new`))
  const [slugTouched, setSlugTouched] = useState(false)
  const [domain, setDomain] = useState('')
  const [theme, setTheme] = useState(suggestedTheme && themes.some((item) => item.name === suggestedTheme) ? suggestedTheme : (themes[0]?.name ?? ''))
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [copied, setCopied] = useState<CopyResult | null>(null)

  async function copy() {
    setSaving(true)
    setError('')
    try {
      setCopied(await api.post<CopyResult>(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/copy`, { name, slug, domain, theme }))
    } catch (reason) {
      setError(messageOf(reason))
    } finally {
      setSaving(false)
    }
  }

  if (copied) {
    return (
      <Dialog
        title="Site copied"
        onClose={() => onOpen(copied.slug)}
        footer={
          <Button variant="primary" onClick={() => onOpen(copied.slug)}>
            Convert the copy
          </Button>
        }
      >
        <div className="grid gap-3 text-sm text-slate-700">
          <p>
            <span className="font-medium">{copied.name}</span> ({copied.domain}, theme {copied.theme}) has {copied.pages} pages, {copied.entries}{' '}
            blog entries and {copied.contentStore} content store items. {site.name} is unchanged.
          </p>
          {copied.warnings.map((warning) => (
            <Alert key={warning} tone="warning">
              {warning}
            </Alert>
          ))}
        </div>
      </Dialog>
    )
  }

  return (
    <Dialog
      title={`Copy ${site.name}`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" onClick={() => void copy()} disabled={saving || !name.trim() || !slug || !domain.trim() || !theme}>
            {saving && <Spinner className="text-white" />}
            Copy site
          </Button>
        </>
      }
    >
      <div className="grid gap-4">
        <p className="text-sm text-slate-600">
          A new site with the same pages, blog entries, content store, menus and settings. {site.name} is only read, so you can
          convert the copy, check it at its own address and switch the domains over later.
        </p>
        <Field label="Name" htmlFor="copy-name">
          <Input
            id="copy-name"
            value={name}
            onChange={(event) => {
              setName(event.target.value)
              if (!slugTouched) setSlug(slugify(event.target.value))
            }}
          />
        </Field>
        <Field label="Slug" htmlFor="copy-slug" help="Lowercase letters, digits and dashes">
          <Input
            id="copy-slug"
            value={slug}
            onChange={(event) => {
              setSlugTouched(true)
              setSlug(event.target.value)
            }}
          />
        </Field>
        <Field label="Domain" htmlFor="copy-domain" help="The host the copy answers to, e.g. new.example.com (a local name like new.localhost works for testing)">
          <Input id="copy-domain" value={domain} placeholder="new.example.com" onChange={(event) => setDomain(event.target.value)} />
        </Field>
        <Field label="Theme" htmlFor="copy-theme">
          <Select id="copy-theme" value={theme} onChange={(event) => setTheme(event.target.value)}>
            {themes.map((item) => (
              <option key={item.name} value={item.name}>
                {item.label}
              </option>
            ))}
          </Select>
        </Field>
        {error && <Alert tone="danger">{error}</Alert>}
      </div>
    </Dialog>
  )
}
