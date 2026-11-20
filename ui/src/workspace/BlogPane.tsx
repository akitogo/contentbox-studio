import { ExternalLink, Newspaper, Plus, Search, Settings2 } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { NewEntryDialog } from '../components/NewEntryDialog'
import { entriesQuery, NO_FILTER, shortDate, type BlogFilter } from '../lib/blog'
import { messageOf, useStudio } from '../studio'
import type { BlogCategory, BlogEntry, BlogEntryList, PageStatus } from '../types'
import { Alert, Badge, Button, Card, cx, IconButton, Input, Loading, Select, Spinner } from '../ui'
import { STATUS } from './status'
import { useWorkspace } from './WorkspaceContext'

/** Entries loaded at first and added by "Show more" */
const PAGE = 50
/** Typing pause before the search runs (ms) */
const SEARCH_DELAY = 250

/**
 * The blog entries of the site, newest first, in the left column (SidePane): search, status and category filters,
 * new entries. Entries open in the same editor as pages. Hidden (not unmounted) while the column shows the pages.
 */
export function BlogPane({ mode, hidden }: { mode: 'full' | 'column'; hidden: boolean }) {
  const { config, api } = useStudio()
  const { site, revision, currentID, openPage } = useWorkspace()
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<BlogFilter>(NO_FILTER)
  const [max, setMax] = useState(PAGE)
  const [list, setList] = useState<BlogEntryList | null>(null)
  const [categories, setCategories] = useState<BlogCategory[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [creating, setCreating] = useState(false)
  const currentRow = useRef<HTMLDivElement>(null)
  const column = mode === 'column'
  const base = site ? `${config.studioApi}/sites/${encodeURIComponent(site.siteID)}` : ''

  function changeFilter(change: Partial<BlogFilter>) {
    setFilter((current) => ({ ...current, ...change }))
    setMax(PAGE)
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setFilter((current) => (current.search === search ? current : { ...current, search }))
      setMax(PAGE)
    }, SEARCH_DELAY)
    return () => window.clearTimeout(timer)
  }, [search])

  useEffect(() => {
    if (!base) return
    let cancelled = false
    setLoading(true)
    api
      .get<BlogEntryList>(`${base}/entries?${entriesQuery(filter, max)}`)
      .then(
        (loaded) => {
          if (cancelled) return
          setList(loaded)
          setError('')
        },
        (e: unknown) => {
          if (!cancelled) setError(messageOf(e))
        },
      )
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [api, base, filter, max, revision])

  useEffect(() => {
    if (!base) return
    api.get<BlogCategory[]>(`${base}/categories`).then(setCategories, () => setCategories([]))
  }, [api, base, revision])

  // Keep the open entry in view when switching to the column
  useEffect(() => {
    if (column && !hidden) currentRow.current?.scrollIntoView({ block: 'nearest' })
  }, [column, hidden, currentID, list])

  const entries = list?.entries ?? []
  const total = list?.total ?? 0
  const filtered = Boolean(filter.search.trim() || filter.status || filter.category)
  const count = `${total} ${total === 1 ? 'entry' : 'entries'}`

  function renderEntry(entry: BlogEntry) {
    const id = entry.contentID
    const status = STATUS[entry.status]
    const isCurrent = currentID === id
    const details = [shortDate(entry.publishedDate), entry.author, entry.categories.map((category) => category.name).join(', ')].filter(Boolean)
    return (
      <li key={id} aria-current={isCurrent ? 'page' : undefined}>
        <div
          ref={isCurrent ? currentRow : undefined}
          className={cx(
            'group flex cursor-pointer items-center gap-3 border-b border-slate-100 py-2 pr-2 pl-3 transition-colors hover:bg-slate-50',
            isCurrent && 'bg-primary-50 shadow-[inset_3px_0_0_var(--color-primary-600)] hover:bg-primary-50',
          )}
          onClick={() => openPage(id)}
        >
          <span className="relative shrink-0" title={status.label}>
            <Newspaper className="size-4 text-slate-400" aria-hidden />
            <span className={cx('absolute -right-0.5 -bottom-0.5 size-2 rounded-full ring-2 ring-white @3xl:hidden', status.dot)} />
          </span>
          <div className="min-w-0 flex-1">
            <a
              href={`${config.appBase}/content/${id}`}
              onClick={(event) => {
                event.preventDefault()
                event.stopPropagation()
                openPage(id)
              }}
              className={cx('block truncate text-sm text-slate-900 no-underline hover:text-primary-700', isCurrent ? 'font-semibold' : 'font-medium')}
            >
              {entry.title}
            </a>
            {details.length > 0 && <p className="truncate text-xs text-slate-500">{details.join(' · ')}</p>}
          </div>
          <div className="hidden shrink-0 items-center gap-1.5 @3xl:flex">
            <Badge tone={status.tone}>{status.label}</Badge>
            {entry.hasBlocks && <Badge tone="primary">Blocks</Badge>}
            {entry.language && (
              <Badge tone="info" className="uppercase">
                {entry.language}
              </Badge>
            )}
          </div>
          <div
            className="flex shrink-0 items-center gap-0.5 opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100"
            onClick={(event) => event.stopPropagation()}
          >
            <a
              href={entry.url}
              target="_blank"
              rel="noreferrer"
              title="View on the site"
              aria-label={`View ${entry.title} on the site`}
              className="inline-flex size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900"
            >
              <ExternalLink className="size-3.5" />
            </a>
            <a
              href={`${config.adminUrl}/entries/editor/contentID/${id}`}
              title="Settings in the classic admin"
              aria-label={`Settings of ${entry.title} in the classic admin`}
              className="hidden size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900 @xl:inline-flex"
            >
              <Settings2 className="size-3.5" />
            </a>
          </div>
        </div>
      </li>
    )
  }

  const listing: ReactNode = !list && loading ? (
    <Loading />
  ) : entries.length ? (
    <>
      <ul aria-label="Blog entries" className={cx('-mb-px transition-opacity', loading && 'opacity-60')}>
        {entries.map(renderEntry)}
      </ul>
      {entries.length < total && (
        <div className="p-3 text-center">
          <Button variant="ghost" size="sm" disabled={loading} onClick={() => setMax((current) => current + PAGE)}>
            Show more ({total - entries.length} left)
          </Button>
        </div>
      )}
    </>
  ) : (
    <p className="px-4 py-12 text-center text-sm text-slate-500">{filtered ? 'No entry matches.' : 'This site has no blog entries yet.'}</p>
  )

  const searchField = (
    <div className="relative min-w-0 flex-1">
      <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-slate-400" aria-hidden />
      <Input type="search" className="pl-8" placeholder="Find an entry" aria-label="Find an entry" value={search} onChange={(event) => setSearch(event.target.value)} />
    </div>
  )

  const statusFilter = (
    <Select aria-label="Status" value={filter.status} onChange={(event) => changeFilter({ status: event.target.value as PageStatus | '' })}>
      <option value="">{column ? 'Status' : 'All statuses'}</option>
      {(Object.keys(STATUS) as PageStatus[]).map((value) => (
        <option key={value} value={value}>
          {STATUS[value].label}
        </option>
      ))}
    </Select>
  )

  const categoryFilter = (
    <Select aria-label="Category" value={filter.category} onChange={(event) => changeFilter({ category: event.target.value })}>
      <option value="">{column ? 'Category' : 'All categories'}</option>
      <option value="none">No category</option>
      {categories.map((category) => (
        <option key={category.categoryID} value={category.categoryID}>
          {category.name} ({category.entries})
        </option>
      ))}
    </Select>
  )

  const alerts = error && <Alert tone="danger">Could not load the blog entries: {error}</Alert>

  return (
    <div role="tabpanel" aria-label="Blog" hidden={hidden} className={cx('min-h-0 flex-1 flex-col', hidden ? 'hidden' : 'flex')}>
      {column ? (
        <>
          <div className="grid gap-2 border-b border-slate-200 p-3">
            <div className="flex items-center gap-1">
              <h2 className="mr-auto flex items-center gap-2 text-sm text-slate-500">
                {list ? count : 'Entries'}
                {loading && list && <Spinner className="size-3.5" />}
              </h2>
              <IconButton label="New entry" onClick={() => setCreating(true)}>
                <Plus className="size-4" />
              </IconButton>
            </div>
            {searchField}
            <div className="grid grid-cols-2 gap-2">
              {statusFilter}
              {categoryFilter}
            </div>
            {alerts}
          </div>
          <div className="min-h-0 flex-1 overflow-auto">{listing}</div>
        </>
      ) : (
        <div className="min-h-0 flex-1 overflow-auto">
          <div className="mx-auto grid max-w-6xl content-start gap-4 px-6 pt-4 pb-6">
            <div className="flex flex-wrap items-end gap-3">
              <div className="mr-auto">
                <h1 className="text-xl font-semibold text-slate-900">Blog</h1>
                <p className="text-sm text-slate-500">
                  {site?.name} · {list ? count : 'loading…'}
                </p>
              </div>
              <div className="w-64">{searchField}</div>
              <div className="w-40">{statusFilter}</div>
              <div className="w-48">{categoryFilter}</div>
              <Button variant="primary" onClick={() => setCreating(true)}>
                <Plus className="size-4" />
                New entry
              </Button>
            </div>
            {alerts}
            <Card className="overflow-hidden">{listing}</Card>
            <p className="text-xs text-slate-500">
              Click an entry to edit it. Categories, excerpt and comments are set in the classic admin for now (gear icon).
            </p>
          </div>
        </div>
      )}

      {site && creating && <NewEntryDialog site={site} onClose={() => setCreating(false)} />}
    </div>
  )
}
