import { useCallback, useEffect, useMemo, useState, type DragEvent } from 'react'
import { Link, useSearchParams } from 'react-router'
import { Header } from '../components/Header'
import { TranslationsPanel } from '../components/TranslationsPanel'
import { applyMove, buildTree, filterPages, keyboardMove, moveFor, type DropPosition, type Move, type TreeNode } from '../lib/tree'
import { messageOf, useStudio } from '../studio'
import type { Site, TreePage as Page } from '../types'

const STATUS_LABELS: Record<Page['status'], string> = {
  published: 'Published',
  draft: 'Draft',
  scheduled: 'Scheduled',
  expired: 'Expired',
}

export function TreePage() {
  const { config, api, me, sites } = useStudio()
  const [params, setParams] = useSearchParams()
  const site: Site | undefined = sites.find((item) => item.slug === params.get('site')) ?? sites[0]

  const [pages, setPages] = useState<Page[]>([])
  const [loading, setLoading] = useState(true)
  const [message, setMessage] = useState<{ kind: 'error' | 'info'; text: string } | null>(null)
  const [search, setSearch] = useState('')
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set())
  const [selectedID, setSelectedID] = useState('')
  const [dragID, setDragID] = useState('')
  const [drop, setDrop] = useState<{ id: string; position: DropPosition } | null>(null)
  const canMove = me.permissions.siteTree

  const load = useCallback(async () => {
    if (!site) return
    setLoading(true)
    try {
      setPages(await api.get<Page[]>(`${config.studioApi}/sites/${encodeURIComponent(site.siteID)}/tree`))
    } catch (error) {
      setMessage({ kind: 'error', text: `Could not load the pages: ${messageOf(error)}` })
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
      setMessage({ kind: 'info', text: `Moved to /${result.slug}` })
      await load()
    } catch (error) {
      setPages(before)
      setMessage({ kind: 'error', text: `Could not move the page: ${messageOf(error)}` })
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
    const dropClass = drop?.id === page.contentID ? ` studio-row--drop-${drop.position}` : ''
    return (
      <li key={page.contentID} role="treeitem" aria-expanded={node.children.length ? !isCollapsed : undefined}>
        <div
          className={`studio-row${selectedID === page.contentID ? ' studio-row--selected' : ''}${dropClass}${dragID === page.contentID ? ' studio-row--dragging' : ''}`}
          style={{ paddingLeft: `${8 + node.depth * 22}px` }}
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
          <button
            type="button"
            className="studio-row__toggle"
            aria-label={isCollapsed ? `Expand ${page.title}` : `Collapse ${page.title}`}
            disabled={!node.children.length}
            onClick={(event) => {
              event.stopPropagation()
              toggle(page.contentID)
            }}
          >
            {node.children.length ? (isCollapsed ? '▸' : '▾') : ''}
          </button>
          <span className="studio-row__title">
            <Link to={`/content/${page.contentID}`} onClick={(event) => event.stopPropagation()}>
              {page.title}
            </Link>
            <small>/{page.slug}</small>
          </span>
          <span className="studio-row__badges">
            <span className={`studio-badge studio-badge--${page.status}`}>{STATUS_LABELS[page.status]}</span>
            {page.hasBlocks && <span className="studio-badge">Blocks</span>}
            {page.language && <span className="studio-badge studio-badge--language">{page.language}</span>}
            {!page.showInMenu && <span className="studio-badge studio-badge--muted">Not in menu</span>}
          </span>
          <span className="studio-row__actions" onClick={(event) => event.stopPropagation()}>
            {canMove && !search && (
              <>
                <button type="button" title="Move up" aria-label={`Move ${page.title} up`} onClick={() => move(page.contentID, keyboardMove(pages, page.contentID, 'up'))}>↑</button>
                <button type="button" title="Move down" aria-label={`Move ${page.title} down`} onClick={() => move(page.contentID, keyboardMove(pages, page.contentID, 'down'))}>↓</button>
                <button type="button" title="Make it a subpage of the page above" aria-label={`Indent ${page.title}`} onClick={() => move(page.contentID, keyboardMove(pages, page.contentID, 'indent'))}>→</button>
                <button type="button" title="Move it up one level" aria-label={`Outdent ${page.title}`} onClick={() => move(page.contentID, keyboardMove(pages, page.contentID, 'outdent'))}>←</button>
              </>
            )}
            <a href={page.url} target="_blank" rel="noreferrer">View</a>
            <a href={`${config.adminUrl}/pages/editor/contentID/${page.contentID}`}>Classic</a>
          </span>
        </div>
        {node.children.length > 0 && !isCollapsed && <ul role="group">{node.children.map(renderNode)}</ul>}
      </li>
    )
  }

  return (
    <div className="studio">
      <Header>
        {sites.length > 1 && (
          <label className="studio-site-switcher">
            Site{' '}
            <select value={site?.slug ?? ''} onChange={(event) => setParams({ site: event.target.value })}>
              {sites.map((item) => (
                <option key={item.siteID} value={item.slug}>
                  {item.name}
                </option>
              ))}
            </select>
          </label>
        )}
      </Header>

      <main className="studio-workspace">
        <section className="studio-panel studio-tree">
          <div className="studio-toolbar">
            <h1>Pages{site ? ` of ${site.name}` : ''}</h1>
            <input
              type="search"
              placeholder="Find a page"
              aria-label="Find a page"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
            <button type="button" onClick={() => setCollapsed(new Set())}>Expand all</button>
            <button type="button" onClick={() => setCollapsed(new Set(pages.map((page) => page.contentID)))}>Collapse all</button>
          </div>
          <p className="studio-message" role="status" aria-live="polite">
            {message && <span className={message.kind === 'error' ? 'studio-error' : 'studio-muted'}>{message.text}</span>}
          </p>
          {canMove ? (
            <p className="studio-muted studio-hint">Drag a page onto another to make it a subpage, or above/below it to reorder. Moving changes the address; the old one redirects.</p>
          ) : (
            <p className="studio-muted studio-hint">You can view the tree; moving pages needs the STUDIO_SITE_TREE permission.</p>
          )}
          {loading && !pages.length ? (
            <p className="studio-muted">Loading…</p>
          ) : tree.length ? (
            <ul className="studio-tree__list" role="tree" aria-label="Pages">
              {tree.map(renderNode)}
            </ul>
          ) : (
            <p className="studio-muted">{search ? 'No page matches.' : 'This site has no pages yet.'}</p>
          )}
        </section>

        {selected && (
          <TranslationsPanel key={selected.contentID} page={selected} onChanged={load} onClose={() => setSelectedID('')} />
        )}
      </main>
    </div>
  )
}
