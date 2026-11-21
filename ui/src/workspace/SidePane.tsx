import { PanelLeftClose, PanelLeftOpen } from 'lucide-react'
import { useRef, useState, type KeyboardEvent, type PointerEvent } from 'react'
import { store, stored } from '../lib/storage'
import { cx, IconButton } from '../ui'
import { BlogPane } from './BlogPane'
import { SiteTreePane } from './SiteTreePane'
import { SECTION_LABELS, useWorkspace, type Section } from './WorkspaceContext'

/** Width of the column next to the editor (px) */
const COLUMN = { default: 300, min: 220, max: 640 }
const STORAGE = { width: 'cbstudio.treeWidth', hidden: 'cbstudio.treeHidden' }

const clampWidth = (width: number) => Math.min(COLUMN.max, Math.max(COLUMN.min, Math.round(width)))

/**
 * Studio's left side: the pages (site tree) or the blog, switched by tabs. `full`: the whole screen (no content open).
 * `column`: next to the editor, resizable by dragging its edge (double-click resets) and collapsible to a strip.
 */
export function SidePane({ mode }: { mode: 'full' | 'column' }) {
  const { section, site } = useWorkspace()
  const [width, setWidth] = useState(() => clampWidth(Number(stored(STORAGE.width)) || COLUMN.default))
  const [hidden, setHidden] = useState(() => stored(STORAGE.hidden) === '1')
  const [resizing, setResizing] = useState(false)
  const resizeStart = useRef({ x: 0, width: 0 })
  // The blog loads once it is first shown, then stays mounted (hidden) like the tree, so both keep their state
  const [blogShown, setBlogShown] = useState(section === 'blog')
  if (section === 'blog' && !blogShown) setBlogShown(true)
  const column = mode === 'column'
  const label = SECTION_LABELS[section]

  function setColumnHidden(value: boolean) {
    setHidden(value)
    store(STORAGE.hidden, value ? '1' : '0')
  }

  function setColumnWidth(value: number) {
    const next = clampWidth(value)
    setWidth(next)
    store(STORAGE.width, String(next))
  }

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

  // Hidden column: a strip to bring it back
  if (column && hidden) {
    return (
      <div className="flex w-10 shrink-0 flex-col items-center gap-3 border-r border-slate-200 bg-white py-2">
        <IconButton label={`Show the ${label.toLowerCase()}`} onClick={() => setColumnHidden(false)}>
          <PanelLeftOpen className="size-4" />
        </IconButton>
        <button
          type="button"
          onClick={() => setColumnHidden(false)}
          className="cursor-pointer text-xs font-medium tracking-wide text-slate-500 [writing-mode:vertical-rl] hover:text-slate-900"
        >
          {label}
        </button>
      </div>
    )
  }

  return (
    <aside
      aria-label={label}
      className={cx(
        '@container relative flex min-h-0 shrink-0 flex-col',
        column ? 'border-r border-slate-200 bg-white' : 'bg-slate-50',
        !resizing && 'transition-[width] duration-300 ease-out',
      )}
      style={{ width: column ? width : '100%' }}
    >
      {column ? (
        <div className="flex items-center gap-2 border-b border-slate-200 px-3 py-2">
          <SectionTabs className="flex-1" />
          <IconButton label={`Hide the ${label.toLowerCase()}`} onClick={() => setColumnHidden(true)}>
            <PanelLeftClose className="size-4" />
          </IconButton>
        </div>
      ) : (
        <div className="mx-auto w-full max-w-6xl px-6 pt-6">
          <SectionTabs />
        </div>
      )}
      <SiteTreePane mode={mode} hidden={section !== 'pages'} />
      {/* A new list per site: its category filter belongs to the site */}
      {blogShown && site?.isBlogEnabled !== false && (
        <BlogPane key={site?.siteID ?? ''} mode={mode} hidden={section !== 'blog'} />
      )}
      {column && (
        <div
          role="separator"
          aria-orientation="vertical"
          aria-label="Width of the column"
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
      )}
      {/* Keeps the editor's iframe from taking the pointer while resizing */}
      {resizing && <div className="fixed inset-0 z-20 cursor-col-resize" />}
    </aside>
  )
}

/** Pages | Blog; the blog tab is disabled when the site's blog is turned off */
function SectionTabs({ className }: { className?: string }) {
  const { section, showSection, site } = useWorkspace()
  const blogOff = site?.isBlogEnabled === false
  return (
    <div role="tablist" aria-label="Content" className={cx('inline-flex rounded-md bg-slate-100 p-0.5', className)}>
      {(Object.keys(SECTION_LABELS) as Section[]).map((value) => {
        const disabled = value === 'blog' && blogOff
        return (
          <button
            key={value}
            type="button"
            role="tab"
            aria-selected={section === value}
            disabled={disabled}
            title={disabled ? 'The blog is turned off for this site (ContentBox site settings)' : undefined}
            onClick={() => showSection(value)}
            className={cx(
              'flex-1 cursor-pointer rounded px-3 py-1 text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:outline-none disabled:cursor-not-allowed disabled:text-slate-300',
              section === value ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-900',
            )}
          >
            {SECTION_LABELS[value]}
          </button>
        )
      })}
    </div>
  )
}
