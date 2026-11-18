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
import { useCallback, useEffect, useMemo, useRef, useState, type DragEvent } from 'react'
import { Link, useSearchParams } from 'react-router'
import { Header } from '../components/Header'
import { NewPageDialog } from '../components/NewPageDialog'
import { TranslationsPanel } from '../components/TranslationsPanel'
import {
  applyMove,
  buildTree,
  filterPages,
  keyboardMove,
  moveFor,
  moveToRootEnd,
  type DropPosition,
  type Move,
  type TreeNode,
} from '../lib/tree'
import { messageOf, useStudio } from '../studio'
import type { Site, TreePage as Page } from '../types'
import { Alert, Badge, Button, Card, cx, IconButton, Input, Loading, Select, type BadgeTone } from '../ui'

const STATUS: Record<Page['status'], { label: string; tone: BadgeTone }> = {
  published: { label: 'Published', tone: 'success' },
  draft: { label: 'Draft', tone: 'neutral' },
  scheduled: { label: 'Scheduled', tone: 'warning' },
  expired: { label: 'Expired', tone: 'danger' },
}

/** Indentation per level and the room for the drag handle (px) */
const INDENT = 24
const ROW_LEFT = 36
/** Center of the expand button of a row at `depth`: where its children's guide line runs */
const guideX = (depth: number) => ROW_LEFT + depth * INDENT + 10
/** Hovering a collapsed page this long while dragging opens it */
const EXPAND_DELAY = 600
/** Drop target id of the "top level" zone below the tree */
const ROOT_END = ''

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
  const expandTimer = useRef<{ id: string; timer: number } | null>(null)
  const canMove = me.permissions.siteTree
  const draggable = canMove && !search

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
    if (target.parentID) {
      setCollapsed((current) => {
        const next = new Set(current)
        next.delete(target.parentID)
        return next
      })
    }
    try {
      const result = await api.post<{ slug: string }>(`${config.studioApi}/pages/${pageID}/move`, target)
      setMessage({ tone: 'success', text: `Moved to /${result.slug}. The old address redirects there.` })
      await load()
    } catch (error) {
      setPages(before)
      setMessage({ tone: 'danger', text: `Could not move the page: ${messageOf(error)}` })
    }
  }

  function cancelExpand() {
    if (expandTimer.current) window.clearTimeout(expandTimer.current.timer)
    expandTimer.current = null
  }

  function scheduleExpand(id: string) {
    if (expandTimer.current?.id === id) return
    cancelExpand()
    expandTimer.current = {
      id,
      timer: window.setTimeout(() => {
        setCollapsed((current) => {
          const next = new Set(current)
          next.delete(id)
          return next
        })
        expandTimer.current = null
      }, EXPAND_DELAY),
    }
  }

  function endDrag() {
    cancelExpand()
    setDragID('')
    setDrop(null)
  }

  /** Top quarter: before; bottom quarter: after (or first child of an open page); middle: inside */
  function positionOf(event: DragEvent<HTMLElement>, open: boolean): DropPosition {
    const box = event.currentTarget.getBoundingClientRect()
    const y = (event.clientY - box.top) / box.height
    if (y < 0.25) return 'before'
    if (y > 0.75) return open ? 'first' : 'after'
    return 'inside'
  }

  function onDragOver(event: DragEvent<HTMLElement>, node: TreeNode, open: boolean) {
    if (!dragID) return
    const id = node.page.contentID
    const position = positionOf(event, open)
    if (!moveFor(pages, dragID, id, position)) {
      if (drop) setDrop(null)
      cancelExpand()
      return
    }
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    if (drop?.id !== id || drop.position !== position) setDrop({ id, position })
    if (position === 'inside' && node.children.length && collapsed.has(id)) scheduleExpand(id)
    else cancelExpand()
  }

  function onDrop(event: DragEvent<HTMLElement>, node: TreeNode, open: boolean) {
    event.preventDefault()
    const target = moveFor(pages, dragID, node.page.contentID, positionOf(event, open))
    const pageID = dragID
    endDrag()
    void move(pageID, target)
  }

  function startDrag(event: DragEvent<HTMLElement>, page: Page) {
    event.dataTransfer.setData('text/plain', page.contentID)
    event.dataTransfer.effectAllowed = 'move'
    // A compact drag preview with the title instead of the whole row
    const ghost = document.createElement('div')
    ghost.textContent = page.title
    ghost.className = 'fixed -top-96 left-0 rounded-md bg-white px-3 py-1.5 text-sm font-medium text-slate-900 shadow-lg ring-1 ring-slate-200'
    document.body.append(ghost)
    event.dataTransfer.setDragImage(ghost, 12, 16)
    window.setTimeout(() => ghost.remove())
    setDragID(page.contentID)
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
    const id = page.contentID
    const hasChildren = node.children.length > 0
    const isCollapsed = collapsed.has(id) && !search
    const open = hasChildren && !isCollapsed
    const status = STATUS[page.status]
    const dropHere = drop?.id === id ? drop.position : null

    return (
      <li key={id} role="treeitem" aria-expanded={hasChildren ? !isCollapsed : undefined} aria-selected={selectedID === id}>
        <div
          className={cx(
            'group relative flex items-center gap-2 border-b border-slate-100 py-2 pr-3 transition-colors hover:bg-slate-50',
            draggable ? 'cursor-grab active:cursor-grabbing' : 'cursor-default',
            selectedID === id && 'bg-primary-50/60 hover:bg-primary-50/80',
            dragID === id && 'opacity-40',
            dropHere === 'inside' && 'bg-primary-50 ring-2 ring-primary-400 ring-inset hover:bg-primary-50',
          )}
          style={{ paddingLeft: ROW_LEFT + node.depth * INDENT }}
          draggable={draggable}
          onDragStart={(event) => startDrag(event, page)}
          onDragEnd={endDrag}
          // A drop target has to accept both dragenter and dragover
          onDragEnter={(event) => onDragOver(event, node, open)}
          onDragOver={(event) => onDragOver(event, node, open)}
          onDrop={(event) => onDrop(event, node, open)}
          onClick={() => setSelectedID(id)}
        >
          {draggable && (
            <GripVertical className="absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-slate-400 group-hover:text-slate-600" aria-hidden />
          )}
          <button
            type="button"
            className={cx(
              'grid size-5 shrink-0 place-items-center rounded text-slate-400',
              hasChildren ? 'cursor-pointer hover:bg-slate-200 hover:text-slate-700' : 'invisible',
            )}
            aria-label={isCollapsed ? `Expand ${page.title}` : `Collapse ${page.title}`}
            disabled={!hasChildren}
            onClick={(event) => {
              event.stopPropagation()
              toggle(id)
            }}
          >
            {isCollapsed ? <ChevronRight className="size-4" /> : <ChevronDown className="size-4" />}
          </button>
          <FileText className="size-4 shrink-0 text-slate-400" aria-hidden />
          <div className="flex min-w-0 flex-1 items-baseline gap-2">
            <Link
              to={`/content/${id}`}
              draggable={false}
              onClick={(event) => event.stopPropagation()}
              className="truncate font-medium text-slate-900 no-underline hover:text-primary-700 hover:underline"
            >
              {page.title}
            </Link>
            <span className="truncate font-mono text-xs text-slate-400">/{page.slug}</span>
            {isCollapsed && (
              <span className="shrink-0 text-xs text-slate-400">
                · {node.children.length} {node.children.length === 1 ? 'subpage' : 'subpages'}
              </span>
            )}
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
          <div
            className={cx(
              'flex shrink-0 items-center gap-0.5 opacity-0 transition-opacity group-focus-within:opacity-100',
              !dragID && 'group-hover:opacity-100',
            )}
            onClick={(event) => event.stopPropagation()}
          >
            {draggable && (
              <>
                <IconButton label="Move up" onClick={() => void move(id, keyboardMove(pages, id, 'up'))}>
                  <ArrowUp className="size-3.5" />
                </IconButton>
                <IconButton label="Move down" onClick={() => void move(id, keyboardMove(pages, id, 'down'))}>
                  <ArrowDown className="size-3.5" />
                </IconButton>
                <IconButton label="Make it a subpage of the page above" onClick={() => void move(id, keyboardMove(pages, id, 'indent'))}>
                  <ArrowRight className="size-3.5" />
                </IconButton>
                <IconButton label="Move it up one level" onClick={() => void move(id, keyboardMove(pages, id, 'outdent'))}>
                  <ArrowLeft className="size-3.5" />
                </IconButton>
              </>
            )}
            <IconButton label="Add a subpage" onClick={() => setNewPageParent(id)}>
              <Plus className="size-3.5" />
            </IconButton>
            <a
              href={page.url}
              target="_blank"
              rel="noreferrer"
              draggable={false}
              title="View"
              aria-label={`View ${page.title}`}
              className="inline-flex size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900"
            >
              <ExternalLink className="size-3.5" />
            </a>
            <a
              href={`${config.adminUrl}/pages/editor/contentID/${id}`}
              draggable={false}
              title="Settings in the classic admin"
              aria-label={`Settings of ${page.title} in the classic admin`}
              className="inline-flex size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900"
            >
              <Settings2 className="size-3.5" />
            </a>
          </div>
          {dropHere === 'before' && <DropLine left={ROW_LEFT + node.depth * INDENT} edge="top" />}
          {dropHere === 'after' && <DropLine left={ROW_LEFT + node.depth * INDENT} edge="bottom" />}
          {dropHere === 'first' && <DropLine left={ROW_LEFT + (node.depth + 1) * INDENT} edge="bottom" />}
        </div>
        {open && (
          <div className="relative">
            <span aria-hidden className="pointer-events-none absolute top-0 bottom-5 w-px bg-slate-200" style={{ left: guideX(node.depth) }} />
            <ul role="group">{node.children.map(renderNode)}</ul>
          </div>
        )}
      </li>
    )
  }

  const rootMove = dragID ? moveToRootEnd(pages, dragID) : null

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
              <ul
                role="tree"
                aria-label="Pages"
                className="-mb-px"
                onDragLeave={(event) => {
                  if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
                    setDrop(null)
                    cancelExpand()
                  }
                }}
              >
                {tree.map(renderNode)}
              </ul>
            ) : (
              <div className="px-6 py-16 text-center">
                <p className="text-sm text-slate-500">{search ? 'No page matches.' : 'This site has no pages yet.'}</p>
              </div>
            )}
            {rootMove && (
              <div
                className={cx(
                  'm-2 rounded-md border border-dashed px-3 py-2.5 text-center text-xs transition-colors',
                  drop?.id === ROOT_END ? 'border-primary-500 bg-primary-50 text-primary-700' : 'border-slate-300 text-slate-500',
                )}
                onDragEnter={(event) => event.preventDefault()}
                onDragOver={(event) => {
                  event.preventDefault()
                  event.dataTransfer.dropEffect = 'move'
                  if (drop?.id !== ROOT_END) setDrop({ id: ROOT_END, position: 'after' })
                }}
                onDragLeave={() => setDrop(null)}
                onDrop={(event) => {
                  event.preventDefault()
                  const pageID = dragID
                  endDrag()
                  void move(pageID, rootMove)
                }}
              >
                Drop here to move it to the top level, at the end
              </div>
            )}
          </Card>
          <p className="text-xs text-slate-500">
            {canMove
              ? 'Drag a page by its row: onto another page to make it a subpage, or to the top or bottom edge of a page to place it before or after. Moving changes the address; the old one redirects.'
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

/** Where a dragged page will land: a line at the depth it gets, with a dot at its start */
function DropLine({ left, edge }: { left: number; edge: 'top' | 'bottom' }) {
  return (
    <span
      aria-hidden
      className={cx('pointer-events-none absolute right-3 z-10 h-0.5 bg-primary-500', edge === 'top' ? '-top-px' : '-bottom-px')}
      style={{ left }}
    >
      <span className="absolute top-1/2 -left-1.5 size-2.5 -translate-y-1/2 rounded-full border-2 border-primary-500 bg-white" />
    </span>
  )
}
