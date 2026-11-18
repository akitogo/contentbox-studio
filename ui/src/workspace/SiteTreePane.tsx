import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  ChevronDown,
  ChevronRight,
  ChevronsDownUp,
  ChevronsUpDown,
  ExternalLink,
  FileText,
  GripVertical,
  PanelLeftClose,
  PanelLeftOpen,
  Plus,
  Search,
  Settings2,
} from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type DragEvent, type KeyboardEvent, type PointerEvent } from 'react'
import { NewPageDialog } from '../components/NewPageDialog'
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
import type { TreePage as Page } from '../types'
import { Alert, Badge, Button, Card, cx, IconButton, Input, Loading, type BadgeTone } from '../ui'
import { useWorkspace } from './WorkspaceContext'

const STATUS: Record<Page['status'], { label: string; tone: BadgeTone; dot: string }> = {
  published: { label: 'Published', tone: 'success', dot: 'bg-emerald-500' },
  draft: { label: 'Draft', tone: 'neutral', dot: 'bg-slate-300' },
  scheduled: { label: 'Scheduled', tone: 'warning', dot: 'bg-amber-500' },
  expired: { label: 'Expired', tone: 'danger', dot: 'bg-red-500' },
}

/** Indentation per level and the room for the drag handle (px) */
const INDENT = 20
const ROW_LEFT = 32
/** Center of the expand button of a row at `depth`: where its children's guide line runs */
const guideX = (depth: number) => ROW_LEFT + depth * INDENT + 10
/** Hovering a collapsed page this long while dragging opens it */
const EXPAND_DELAY = 600
/** Drop target id of the "top level" zone below the tree */
const ROOT_END = ''
/** Width of the column next to the editor (px) */
const COLUMN = { default: 300, min: 220, max: 640 }
const STORAGE = { width: 'cbstudio.treeWidth', hidden: 'cbstudio.treeHidden' }

/** Per-viewer layout memory; the page works without it */
function stored(key: string): string | null {
  try {
    return window.localStorage.getItem(key)
  } catch {
    return null
  }
}

function store(key: string, value: string) {
  try {
    window.localStorage.setItem(key, value)
  } catch {
    // private mode or blocked storage: the layout is just not remembered
  }
}

const clampWidth = (width: number) => Math.min(COLUMN.max, Math.max(COLUMN.min, Math.round(width)))

/**
 * The site's pages as a tree. `full`: the whole screen (no content open). `column`: next to the editor, resizable by
 * dragging its edge and collapsible; rows show more (address, badges, move buttons) the wider it is.
 */
export function SiteTreePane({ mode }: { mode: 'full' | 'column' }) {
  const { config, api, me } = useStudio()
  const { site, pages, setPages, loading, loadError, reload, currentID, openPage } = useWorkspace()
  const [message, setMessage] = useState<{ tone: 'danger' | 'success'; text: string } | null>(null)
  const [search, setSearch] = useState('')
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set())
  const [dragID, setDragID] = useState('')
  const [drop, setDrop] = useState<{ id: string; position: DropPosition } | null>(null)
  const [newPageParent, setNewPageParent] = useState<string | null>(null)
  const [width, setWidth] = useState(() => clampWidth(Number(stored(STORAGE.width)) || COLUMN.default))
  const [hidden, setHidden] = useState(() => stored(STORAGE.hidden) === '1')
  const [resizing, setResizing] = useState(false)
  const resizeStart = useRef({ x: 0, width: 0 })
  const expandTimer = useRef<{ id: string; timer: number } | null>(null)
  const currentRow = useRef<HTMLDivElement>(null)
  const canMove = me.permissions.siteTree
  const draggable = canMove && !search

  const visible = useMemo(() => filterPages(pages, search), [pages, search])
  const tree = useMemo(() => buildTree(visible), [visible])

  // Keep the open page in view when switching to the column
  useEffect(() => {
    if (mode === 'column') currentRow.current?.scrollIntoView({ block: 'nearest' })
  }, [mode, currentID])

  function setColumnHidden(value: boolean) {
    setHidden(value)
    store(STORAGE.hidden, value ? '1' : '0')
  }

  function setColumnWidth(value: number) {
    const next = clampWidth(value)
    setWidth(next)
    store(STORAGE.width, String(next))
  }

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
      await reload()
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

  // Resizing the column by its right edge (pointer or arrow keys; double-click resets)
  function startResize(event: PointerEvent<HTMLDivElement>) {
    event.preventDefault()
    event.currentTarget.setPointerCapture(event.pointerId)
    resizeStart.current = { x: event.clientX, width }
    setResizing(true)
  }

  function resize(event: PointerEvent<HTMLDivElement>) {
    if (resizing) setWidth(clampWidth(resizeStart.current.width + event.clientX - resizeStart.current.x))
  }

  function endResize(event: PointerEvent<HTMLDivElement>) {
    if (!resizing) return
    event.currentTarget.releasePointerCapture(event.pointerId)
    setResizing(false)
    setColumnWidth(resizeStart.current.width + event.clientX - resizeStart.current.x)
  }

  function resizeByKey(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === 'ArrowLeft') setColumnWidth(width - 16)
    else if (event.key === 'ArrowRight') setColumnWidth(width + 16)
    else return
    event.preventDefault()
  }

  function renderNode(node: TreeNode) {
    const { page } = node
    const id = page.contentID
    const hasChildren = node.children.length > 0
    const isCollapsed = collapsed.has(id) && !search
    const open = hasChildren && !isCollapsed
    const status = STATUS[page.status]
    const dropHere = drop?.id === id ? drop.position : null
    const isCurrent = currentID === id

    return (
      <li key={id} role="treeitem" aria-expanded={hasChildren ? !isCollapsed : undefined} aria-selected={isCurrent}>
        <div
          ref={isCurrent ? currentRow : undefined}
          className={cx(
            'group relative flex items-center gap-2 border-b border-slate-100 py-1.5 pr-2 transition-colors hover:bg-slate-50',
            draggable ? 'cursor-grab active:cursor-grabbing' : 'cursor-pointer',
            isCurrent && 'bg-primary-50 shadow-[inset_3px_0_0_var(--color-primary-600)] hover:bg-primary-50',
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
          onClick={() => openPage(id)}
        >
          {draggable && (
            <GripVertical className="absolute top-1/2 left-2 size-4 -translate-y-1/2 text-slate-300 group-hover:text-slate-500" aria-hidden />
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
          <span className="relative shrink-0" title={status.label}>
            <FileText className="size-4 text-slate-400" aria-hidden />
            <span className={cx('absolute -right-0.5 -bottom-0.5 size-2 rounded-full ring-2 ring-white @3xl:hidden', status.dot)} />
          </span>
          <div className="flex min-w-0 flex-1 items-baseline gap-2">
            <a
              href={`${config.appBase}/content/${id}`}
              draggable={false}
              aria-current={isCurrent ? 'page' : undefined}
              onClick={(event) => {
                event.preventDefault()
                event.stopPropagation()
                openPage(id)
              }}
              className={cx('truncate text-slate-900 no-underline hover:text-primary-700', isCurrent ? 'font-semibold' : 'font-medium')}
            >
              {page.title}
            </a>
            <span className="hidden truncate font-mono text-xs text-slate-400 @md:inline">/{page.slug}</span>
            {isCollapsed && <span className="shrink-0 text-xs text-slate-400">{node.children.length}</span>}
          </div>
          <div className="hidden shrink-0 items-center gap-1.5 @3xl:flex">
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
              <div className="hidden items-center gap-0.5 @3xl:flex">
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
              </div>
            )}
            <IconButton label="Add a subpage" onClick={() => setNewPageParent(id)}>
              <Plus className="size-3.5" />
            </IconButton>
            <a
              href={page.url}
              target="_blank"
              rel="noreferrer"
              draggable={false}
              title="View on the site"
              aria-label={`View ${page.title} on the site`}
              className="inline-flex size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900"
            >
              <ExternalLink className="size-3.5" />
            </a>
            <a
              href={`${config.adminUrl}/pages/editor/contentID/${id}`}
              draggable={false}
              title="Settings in the classic admin"
              aria-label={`Settings of ${page.title} in the classic admin`}
              className="hidden size-7 items-center justify-center rounded-md text-slate-500 hover:bg-slate-100 hover:text-slate-900 @xl:inline-flex"
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
            <span aria-hidden className="pointer-events-none absolute top-0 bottom-4 w-px bg-slate-200" style={{ left: guideX(node.depth) }} />
            <ul role="group">{node.children.map(renderNode)}</ul>
          </div>
        )}
      </li>
    )
  }

  const rootMove = dragID ? moveToRootEnd(pages, dragID) : null
  const column = mode === 'column'

  // Hidden column: a strip to bring it back
  if (column && hidden) {
    return (
      <div className="flex w-10 shrink-0 flex-col items-center gap-3 border-r border-slate-200 bg-white py-2">
        <IconButton label="Show the pages" onClick={() => setColumnHidden(false)}>
          <PanelLeftOpen className="size-4" />
        </IconButton>
        <button
          type="button"
          onClick={() => setColumnHidden(false)}
          className="cursor-pointer text-xs font-medium tracking-wide text-slate-500 [writing-mode:vertical-rl] hover:text-slate-900"
        >
          Pages
        </button>
      </div>
    )
  }

  const list = loading && !pages.length ? (
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
    <p className="px-4 py-12 text-center text-sm text-slate-500">{search ? 'No page matches.' : 'This site has no pages yet.'}</p>
  )

  const rootZone = rootMove && (
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
      Drop here to move it to the top level
    </div>
  )

  const searchField = (
    <div className="relative min-w-0 flex-1">
      <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-slate-400" aria-hidden />
      <Input type="search" className="pl-8" placeholder="Find a page" aria-label="Find a page" value={search} onChange={(event) => setSearch(event.target.value)} />
    </div>
  )

  const alerts = (
    <>
      {loadError && <Alert tone="danger">Could not load the pages: {loadError}</Alert>}
      {message && (
        <Alert tone={message.tone} onClose={() => setMessage(null)}>
          {message.text}
        </Alert>
      )}
    </>
  )

  return (
    <aside
      aria-label="Pages"
      className={cx(
        '@container relative flex min-h-0 shrink-0 flex-col',
        column ? 'border-r border-slate-200 bg-white' : 'bg-slate-50',
        !resizing && 'transition-[width] duration-300 ease-out',
      )}
      style={{ width: column ? width : '100%' }}
    >
      {column ? (
        <>
          <div className="grid gap-2 border-b border-slate-200 p-3">
            <div className="flex items-center gap-1">
              <h2 className="mr-auto text-sm font-semibold text-slate-900">
                Pages <span className="font-normal text-slate-400">{pages.length}</span>
              </h2>
              <IconButton label="New page" onClick={() => setNewPageParent('')}>
                <Plus className="size-4" />
              </IconButton>
              <IconButton label="Expand all" onClick={() => setCollapsed(new Set())}>
                <ChevronsUpDown className="size-4" />
              </IconButton>
              <IconButton label="Collapse all" onClick={() => setCollapsed(new Set(pages.map((page) => page.contentID)))}>
                <ChevronsDownUp className="size-4" />
              </IconButton>
              <IconButton label="Hide the pages" onClick={() => setColumnHidden(true)}>
                <PanelLeftClose className="size-4" />
              </IconButton>
            </div>
            {searchField}
            {alerts}
          </div>
          <div className="min-h-0 flex-1 overflow-auto">
            {list}
            {rootZone}
          </div>
          <div
            role="separator"
            aria-orientation="vertical"
            aria-label="Width of the pages column"
            aria-valuenow={width}
            aria-valuemin={COLUMN.min}
            aria-valuemax={COLUMN.max}
            tabIndex={0}
            title="Drag to resize, double-click to reset"
            className={cx(
              'absolute inset-y-0 -right-1 z-30 w-2 cursor-col-resize touch-none outline-none hover:bg-primary-500/30 focus-visible:bg-primary-500/40',
              resizing && 'bg-primary-500/40',
            )}
            onPointerDown={startResize}
            onPointerMove={resize}
            onPointerUp={endResize}
            onPointerCancel={endResize}
            onDoubleClick={() => setColumnWidth(COLUMN.default)}
            onKeyDown={resizeByKey}
          />
          {/* Keeps the editor's iframe from taking the pointer while resizing */}
          {resizing && <div className="fixed inset-0 z-20 cursor-col-resize" />}
        </>
      ) : (
        <div className="min-h-0 flex-1 overflow-auto">
          <div className="mx-auto grid max-w-6xl content-start gap-4 px-6 py-6">
            <div className="flex flex-wrap items-end gap-3">
              <div className="mr-auto">
                <h1 className="text-xl font-semibold text-slate-900">Pages</h1>
                <p className="text-sm text-slate-500">
                  {site?.name} · {pages.length} {pages.length === 1 ? 'page' : 'pages'}
                </p>
              </div>
              <div className="w-64">{searchField}</div>
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
            {alerts}
            <Card className="overflow-hidden">
              {list}
              {rootZone}
            </Card>
            <p className="text-xs text-slate-500">
              {canMove
                ? 'Click a page to edit it. Drag a page by its row: onto another page to make it a subpage, or to the top or bottom edge of a page to place it before or after. Moving changes the address; the old one redirects.'
                : 'Click a page to edit it. Moving pages needs the STUDIO_SITE_TREE permission.'}
            </p>
          </div>
        </div>
      )}

      {site && newPageParent !== null && (
        <NewPageDialog site={site} pages={pages} parentID={newPageParent} onClose={() => setNewPageParent(null)} />
      )}
    </aside>
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
