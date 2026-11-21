import {
  ChevronDown,
  ChevronRight,
  ChevronsDownUp,
  ChevronsUpDown,
  ExternalLink,
  FileText,
  GripVertical,
  Menu,
  Plus,
  Search,
  Settings2,
} from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type DragEvent } from 'react'
import { NewPageDialog } from '../components/NewPageDialog'
import {
  applyMove,
  buildTree,
  filterPages,
  moveFor,
  moveToRootEnd,
  type DropPosition,
  type Move,
  type TreeNode,
} from '../lib/tree'
import { messageOf, useStudio } from '../studio'
import type { TreePage as Page } from '../types'
import { Alert, cx, IconButton, Input, Loading } from '../ui'
import { STATUS } from './status'
import { useWorkspace } from './WorkspaceContext'

/** Indentation per level and the room for the drag handle (px) */
const INDENT = 20
const ROW_LEFT = 32
/** Center of the expand button of a row at `depth`: where its children's guide line runs */
const guideX = (depth: number) => ROW_LEFT + depth * INDENT + 10
/** Hovering a collapsed page this long while dragging opens it */
const EXPAND_DELAY = 600
/** Drop target id of the "top level" zone below the tree */
const ROOT_END = ''

/**
 * The site's pages as a tree, in the column next to the editor (SidePane); rows show the address when the column is
 * wide enough. Pages are moved by dragging. Hidden (not unmounted) while the column shows the blog, so open folders and
 * the search stay.
 */
export function SiteTreePane({ hidden }: { hidden: boolean }) {
  const { config, api, me } = useStudio()
  const { site, pages, setPages, loading, loadError, reload, currentID, openPage } = useWorkspace()
  const [message, setMessage] = useState<{ tone: 'danger' | 'success'; text: string } | null>(null)
  const [search, setSearch] = useState('')
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set())
  const [dragID, setDragID] = useState('')
  const [drop, setDrop] = useState<{ id: string; position: DropPosition } | null>(null)
  const [newPageParent, setNewPageParent] = useState<string | null>(null)
  const expandTimer = useRef<{ id: string; timer: number } | null>(null)
  const currentRow = useRef<HTMLDivElement>(null)
  const canMove = me.permissions.siteTree
  const draggable = canMove && !search

  const visible = useMemo(() => filterPages(pages, search), [pages, search])
  const tree = useMemo(() => buildTree(visible), [visible])

  // Keep the open page in view
  useEffect(() => {
    if (!hidden) currentRow.current?.scrollIntoView({ block: 'nearest' })
  }, [currentID, hidden])

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
            <span className={cx('absolute -right-0.5 -bottom-0.5 size-2 rounded-full ring-2 ring-white', status.dot)} />
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
            <MenuIndicator inMenu={page.showInMenu} />
            {page.language && <LanguageTag language={page.language} />}
            <span className="hidden truncate font-mono text-xs text-slate-400 @md:inline">/{page.slug}</span>
            {isCollapsed && <span className="shrink-0 text-xs text-slate-400">{node.children.length}</span>}
          </div>
          <div
            className={cx(
              'flex shrink-0 items-center gap-0.5 opacity-0 transition-opacity group-focus-within:opacity-100',
              !dragID && 'group-hover:opacity-100',
            )}
            onClick={(event) => event.stopPropagation()}
          >
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
    <div role="tabpanel" aria-label="Pages" hidden={hidden} className={cx('min-h-0 flex-1 flex-col', hidden ? 'hidden' : 'flex')}>
      <div className="grid gap-2 border-b border-slate-200 p-3">
        <div className="flex items-center gap-1">
          <h2 className="mr-auto text-sm text-slate-500">
            {pages.length} {pages.length === 1 ? 'page' : 'pages'}
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
        </div>
        {searchField}
        {alerts}
      </div>
      <div className="min-h-0 flex-1 overflow-auto">
        {list}
        {rootZone}
      </div>

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

/** Whether the page is in the site's menu: a menu icon, struck through when it is not; at every width of the tree */
function MenuIndicator({ inMenu }: { inMenu: boolean }) {
  const label = inMenu ? "In the site's menu" : "Not in the site's menu"
  return (
    <span className="relative inline-flex shrink-0 self-center" title={label}>
      <Menu className={cx('size-3.5', inMenu ? 'text-slate-500' : 'text-slate-300')} aria-hidden />
      {!inMenu && <span className="absolute top-1/2 left-1/2 h-px w-4.5 -translate-x-1/2 -translate-y-1/2 -rotate-45 bg-slate-400" aria-hidden />}
      <span className="sr-only">{label}</span>
    </span>
  )
}

/** The page's language, as a small tag */
export function LanguageTag({ language }: { language: string }) {
  return (
    <span className="shrink-0 self-center rounded bg-sky-50 px-1 text-[10px] leading-4 font-medium text-sky-700 uppercase" title={`Language: ${language}`}>
      {language}
    </span>
  )
}
