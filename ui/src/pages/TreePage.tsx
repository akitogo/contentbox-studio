import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  ChevronDown,
  ChevronRight,
  ExternalLink,
  FileText,
  GripVertical,
  Plus,
  Search,
  Settings2,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState, type DragEvent } from 'react'
import { Link, useSearchParams } from 'react-router'
import { Header } from '../components/Header'
import { NewPageDialog } from '../components/NewPageDialog'
import { TranslationsPanel } from '../components/TranslationsPanel'
import { applyMove, buildTree, filterPages, keyboardMove, moveFor, type DropPosition, type Move, type TreeNode } from '../lib/tree'
import { messageOf, useStudio } from '../studio'
import type { Site, TreePage as Page } from '../types'
import { Alert, Badge, Button, Card, cx, IconButton, Input, Loading, Select, type BadgeTone } from '../ui'

const STATUS: Record<Page['status'], { label: string; tone: BadgeTone }> = {
  published: { label: 'Published', tone: 'success' },
  draft: { label: 'Draft', tone: 'neutral' },
  scheduled: { label: 'Scheduled', tone: 'warning' },
  expired: { label: 'Expired', tone: 'danger' },
}

const DROP_CLASSES: Record<DropPosition, string> = {
  before: 'shadow-[inset_0_2px_0_var(--color-primary-500)]',
  after: 'shadow-[inset_0_-2px_0_var(--color-primary-500)]',
  inside: 'bg-primary-50 ring-1 ring-primary-400 ring-inset',
}

export function TreePage() {
  const { config, api, me, sites } = useStudio()
  const [params, setParams] = useSearchParams()
  const site: Site | undefined = sites.find((item) => item.slug === params.get('site')) ?? sites[0]

  const [pages, setPages] = useState<Page[]>([])
  const [loading, setLoading] = useState(true)
  const [message, setMessage] = useState<{ tone: 'danger' | 'success'; text: string } | null>(null)
  const [search, setSearch] = useState('')
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set())
  const [selectedID, setSelectedID] = useState('')
  const [dragID, setDragID] = useState('')
  const [drop, setDrop] = useState<{ id: string; position: DropPosition } | null>(null)
  const [newPageParent, setNewPageParent] = useState<string | null>(null)
  const canMove = me.permissions.siteTree

  const load = useCallback(async () => {
    if (!site) return
    setLoading(true)
    try {
      setPages(await api.get<Page[]>(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/tree`))
    } catch (error) {
      setMessage({ tone: 'danger', text: `Could not load the pages: ${messageOf(error)}` })
    } finally {
      setLoading(false)
    }
  }, [api, config, site])

  useEffect(() => {
    void load()
    setSelectedID('')
  }, [load])

  const visible = useMemo(() => filterPages(pages, search), [pages, search])
  const tree = useMemo(() => buildTree(visible), [visible])
  const selected = pages.find((page) => page.contentID === selectedID)

  async function move(pageID: string, target: Move | null) {
    if (!target) return
    const before = pages
    setPages(applyMove(pages, pageID, target))
    try {
      const result = await api.post<{ slug: string }>(`${config.studioApi}/pages/${pageID}/move`, target)
      setMessage({ tone: 'success', text: `Moved to /${result.slug}. The old address redirects there.` })
      await load()
    } catch (error) {
      setPages(before)
      setMessage({ tone: 'danger', text: `Could not move the page: ${messageOf(error)}` })
    }
  }

  function positionOf(event: DragEvent<HTMLElement>): DropPosition {
    const box = event.currentTarget.getBoundingClientRect()
    const y = (event.clientY - box.top) / box.height
    return y < 0.25 ? 'before' : y > 0.75 ? 'after' : 'inside'
  }

  function onDragOver(event: DragEvent<HTMLElement>, targetID: string) {
    if (!dragID) return
    const position = positionOf(event)
    if (!moveFor(pages, dragID, targetID, position)) {
      setDrop(null)
      return
    }
    event.preventDefault()
    if (drop?.id !== targetID || drop.position !== position) setDrop({ id: targetID, position })
  }

  function onDrop(event: DragEvent<HTMLElement>, targetID: string) {
    event.preventDefault()
    const target = moveFor(pages, dragID, targetID, positionOf(event))
    const pageID = dragID
    setDragID('')
    setDrop(null)
    void move(pageID, target)
  }

  function toggle(id: string) {
    setCollapsed((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function renderNode(node: TreeNode) {
    const { page } = node
    const isCollapsed = collapsed.has(page.contentID) && !search
    const status = STATUS[page.status]
    return (
      <li key={page.contentID} role="treeitem" aria-expanded={node.children.length ? !isCollapsed : undefined} aria-selected={selectedID === page.contentID}>
        <div
          className={cx(
            'group flex cursor-default items-center gap-2 border-b border-slate-100 py-2 pr-3 transition-colors hover:bg-slate-50',
            selectedID === page.contentID && 'bg-primary-50/60 hover:bg-primary-50/80',
            dragID === page.contentID && 'opacity-40',
            drop?.id === page.contentID && DROP_CLASSES[drop.position],
          )}
          style={{ paddingLeft: `${12 + node.depth * 22}px` }}
          draggable={canMove && !search}
          onDragStart={(event) => {
            event.dataTransfer.setData('text/plain', page.contentID)
            event.dataTransfer.effectAllowed = 'move'
            setDragID(page.contentID)
          }}
          onDragEnd={() => {
            setDragID('')
            setDrop(null)
          }}
          onDragOver={(event) => onDragOver(event, page.contentID)}
          onDragLeave={() => setDrop(null)}
          onDrop={(event) => onDrop(event, page.contentID)}
          onClick={() => setSelectedID(page.contentID)}
        >
          {canMove && !search && <GripVertical className="size-4 shrink-0 cursor-grab text-slate-300 group-hover:text-slate-500" aria-hidden />}
          <button
            type="button"
            className={cx('grid size-5 shrink-0 place-items-center rounded text-slate-400', node.children.length ? 'cursor-pointer hover:bg-slate-200 hover:text-slate-700' : 'invisible')}
            aria-label={isCollapsed ? `Expand ${page.title}` : `Collapse ${page.title}`}
            disabled={!node.children.length}
            onClick={(event) => {
              event.stopPropagation()
              toggle(page.contentID)
            }}
          >
            {isCollapsed ? <ChevronRight className="size-4" /> : <ChevronDown className="size-4" />}
          </button>
          <FileText className="size-4 shrink-0 text-slate-400" aria-hidden />
          <div className="flex min-w-0 flex-1 items-baseline gap-2">
            <Link
              to={`/content/${page.contentID}`}
              onClick={(event) => event.stopPropagation()}
              className="truncate font-medium text-slate-900 no-underline hover:text-primary-700 hover:underline"
            >
              {page.title}
            </Link>
            <span className="truncate font-mono text-xs text-slate-400">/{page.slug}</span>
          </div>
          <div className="hidden shrink-0 items-center gap-1.5 md:flex">
            <Badge tone={status.tone}>{status.label}</Badge>
            {page.hasBlocks && <Badge tone="primary">Blocks</Badge>}
            {page.language && (
              <Badge tone="info" className="uppercase">
                {page.language}
              </Badge>
            )}
            {!page.showInMenu && <Badge>Hidden in menu</Badge>}
          </div>
          <div className="flex shrink-0 items-center gap-0.5 opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100" onClick={(event) => event.stopPropagation()}>
            {canMove && !search && (
              <>
                <IconButton label="Move up" onClick={() => void move(page.contentID, keyboardMove(pages, page.contentID, 'up'))}>
                  <ArrowUp className="size-3.5" />
                </IconButton>
                <IconButton label="Move down" onClick={() => void move(page.contentID, keyboardMove(pages, page.contentID, 'down'))}>
                  <ArrowDown className="size-3.5" />
                </IconButton>
                <IconButton label="Make it a subpage of the page above" onClick={() => void move(page.contentID, keyboardMove(pages, page.contentID, 'indent'))}>
                  <ArrowRight className="size-3.5" />
                </IconButton>
                <IconButton label="Move it up one level" onClick={() => void move(page.contentID, keyboardMove(pages, page.contentID, 'outdent'))}>
                  <ArrowLeft className="size-3.5" />
                </IconButton>
              </>
            )}
            <IconButton label="Add a subpage" onClick={() => setNewPageParent(page.contentID)}>
              <Plus className="size-3.5" />
            </IconButton>
            <a href={page.url} target="_blank" rel="noreferrer" title="View" aria-label={`View ${page.title}`} className="inline-flex size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900">
              <ExternalLink className="size-3.5" />
            </a>
            <a
              href={`${config.adminUrl}/pages/editor/contentID/${page.contentID}`}
              title="Settings in the classic admin"
              aria-label={`Settings of ${page.title} in the classic admin`}
              className="inline-flex size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900"
            >
              <Settings2 className="size-3.5" />
            </a>
          </div>
        </div>
        {node.children.length > 0 && !isCollapsed && <ul role="group">{node.children.map(renderNode)}</ul>}
      </li>
    )
  }

  return (
    <div className="min-h-screen">
      <Header>
        {sites.length > 1 && (
          <Select className="h-8 w-56" value={site?.slug ?? ''} onChange={(event) => setParams({ site: event.target.value })} aria-label="Site">
            {sites.map((item) => (
              <option key={item.siteID} value={item.slug}>
                {item.name}
              </option>
            ))}
          </Select>
        )}
      </Header>

      <main className={cx('mx-auto grid max-w-7xl gap-6 px-6 py-6', selected && 'lg:grid-cols-[minmax(0,1fr)_22rem]')}>
        <div className="grid min-w-0 content-start gap-4">
          <div className="flex flex-wrap items-end gap-3">
            <div className="mr-auto">
              <h1 className="text-xl font-semibold text-slate-900">Pages</h1>
              <p className="text-sm text-slate-500">
                {site?.name} · {pages.length} {pages.length === 1 ? 'page' : 'pages'}
              </p>
            </div>
            <div className="relative">
              <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-slate-400" aria-hidden />
              <Input type="search" className="w-64 pl-8" placeholder="Find a page" aria-label="Find a page" value={search} onChange={(event) => setSearch(event.target.value)} />
            </div>
            <Button variant="ghost" onClick={() => setCollapsed(new Set())}>
              Expand all
            </Button>
            <Button variant="ghost" onClick={() => setCollapsed(new Set(pages.map((page) => page.contentID)))}>
              Collapse all
            </Button>
            <Button variant="primary" onClick={() => setNewPageParent('')}>
              <Plus className="size-4" />
              New page
            </Button>
          </div>

          {message && (
            <Alert tone={message.tone} onClose={() => setMessage(null)}>
              {message.text}
            </Alert>
          )}

          <Card className="overflow-hidden">
            {loading && !pages.length ? (
              <Loading />
            ) : tree.length ? (
              <ul role="tree" aria-label="Pages" className="-mb-px">
                {tree.map(renderNode)}
              </ul>
            ) : (
              <div className="px-6 py-16 text-center">
                <p className="text-sm text-slate-500">{search ? 'No page matches.' : 'This site has no pages yet.'}</p>
              </div>
            )}
          </Card>
          <p className="text-xs text-slate-500">
            {canMove
              ? 'Drag a page onto another to make it a subpage, or above or below it to reorder. Moving changes the address; the old one redirects.'
              : 'Moving pages needs the STUDIO_SITE_TREE permission.'}
          </p>
        </div>

        {selected && <TranslationsPanel key={selected.contentID} page={selected} onChanged={load} onClose={() => setSelectedID('')} />}
      </main>

      {site && newPageParent !== null && (
        <NewPageDialog site={site} pages={pages} parentID={newPageParent} onClose={() => setNewPageParent(null)} />
      )}
    </div>
  )
}
