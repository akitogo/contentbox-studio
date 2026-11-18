/**
 * Page tree logic, independent of React: building the tree from the flat API list, where a drop moves a page,
 * and applying a move locally until the server's answer arrives.
 */
import type { TreePage } from '../types'

export interface TreeNode {
  page: TreePage
  children: TreeNode[]
  depth: number
}

/** Next to the target, as its last child (inside) or as its first child (first) */
export type DropPosition = 'before' | 'after' | 'inside' | 'first'

/** Server move request: new parent ("" for the root) and 0-based position among the new siblings */
export interface Move {
  parentID: string
  index: number
}

const bySortOrder = (a: TreePage, b: TreePage) =>
  a.order === b.order ? a.title.localeCompare(b.title) : a.order - b.order

/** Children of a parent ("" for the root) in display order */
export function childrenOf(pages: TreePage[], parentID: string): TreePage[] {
  return pages.filter((page) => page.parentID === parentID).sort(bySortOrder)
}

export function buildTree(pages: TreePage[]): TreeNode[] {
  const known = new Set(pages.map((page) => page.contentID))
  // Pages whose parent is not in the list (e.g. filtered out) are shown at the root
  const parentOf = (page: TreePage) => (known.has(page.parentID) ? page.parentID : '')
  const normalized = pages.map((page) => ({ ...page, parentID: parentOf(page) }))
  const build = (parentID: string, depth: number): TreeNode[] =>
    childrenOf(normalized, parentID).map((page) => ({
      page,
      depth,
      children: build(page.contentID, depth + 1),
    }))
  return build('', 0)
}

/** True if `candidate` is `ancestorID` itself or below it */
export function isWithin(pages: TreePage[], candidateID: string, ancestorID: string): boolean {
  const parents = new Map(pages.map((page) => [page.contentID, page.parentID]))
  let current: string | undefined = candidateID
  const seen = new Set<string>()
  while (current && !seen.has(current)) {
    if (current === ancestorID) return true
    seen.add(current)
    current = parents.get(current)
  }
  return false
}

/**
 * Where dropping `draggedID` on `targetID` at `position` moves it, or null if that is not possible
 * (onto itself or into its own subtree) or would leave the page where it is
 */
export function moveFor(pages: TreePage[], draggedID: string, targetID: string, position: DropPosition): Move | null {
  const target = pages.find((page) => page.contentID === targetID)
  const dragged = pages.find((page) => page.contentID === draggedID)
  if (!target || !dragged || draggedID === targetID) return null

  let move: Move
  if (position === 'inside' || position === 'first') {
    if (isWithin(pages, targetID, draggedID)) return null
    const siblings = childrenOf(pages, targetID).filter((page) => page.contentID !== draggedID)
    move = { parentID: targetID, index: position === 'first' ? 0 : siblings.length }
  } else {
    if (target.parentID && isWithin(pages, target.parentID, draggedID)) return null
    const siblings = childrenOf(pages, target.parentID).filter((page) => page.contentID !== draggedID)
    const targetIndex = siblings.findIndex((page) => page.contentID === targetID)
    move = { parentID: target.parentID, index: targetIndex + (position === 'after' ? 1 : 0) }
  }

  const currentIndex = childrenOf(pages, dragged.parentID).findIndex((page) => page.contentID === draggedID)
  return move.parentID === dragged.parentID && move.index === currentIndex ? null : move
}

/** Moving a page to the end of the top level, or null if it is already there */
export function moveToRootEnd(pages: TreePage[], draggedID: string): Move | null {
  const roots = childrenOf(pages, '')
  const last = roots[roots.length - 1]
  return last ? moveFor(pages, draggedID, last.contentID, 'after') : null
}

/** Keyboard moves: one up/down among siblings, into the previous sibling (indent), next to the parent (outdent) */
export function keyboardMove(
  pages: TreePage[],
  pageID: string,
  direction: 'up' | 'down' | 'indent' | 'outdent',
): Move | null {
  const page = pages.find((item) => item.contentID === pageID)
  if (!page) return null
  const siblings = childrenOf(pages, page.parentID)
  const index = siblings.findIndex((item) => item.contentID === pageID)

  switch (direction) {
    case 'up':
      return index > 0 ? { parentID: page.parentID, index: index - 1 } : null
    case 'down':
      return index < siblings.length - 1 ? { parentID: page.parentID, index: index + 1 } : null
    case 'indent': {
      const previous = siblings[index - 1]
      return previous ? { parentID: previous.contentID, index: childrenOf(pages, previous.contentID).length } : null
    }
    case 'outdent': {
      if (!page.parentID) return null
      const parent = pages.find((item) => item.contentID === page.parentID)
      if (!parent) return null
      const parentSiblings = childrenOf(pages, parent.parentID)
      return { parentID: parent.parentID, index: parentSiblings.findIndex((item) => item.contentID === parent.contentID) + 1 }
    }
  }
}

/** The list after a move, as the server will store it (parent changed, new siblings renumbered from 1) */
export function applyMove(pages: TreePage[], pageID: string, move: Move): TreePage[] {
  const moving = pages.find((page) => page.contentID === pageID)
  if (!moving) return pages
  const siblings = childrenOf(pages, move.parentID).filter((page) => page.contentID !== pageID)
  siblings.splice(Math.min(Math.max(move.index, 0), siblings.length), 0, { ...moving, parentID: move.parentID })
  const order = new Map(siblings.map((page, i) => [page.contentID, i + 1]))
  return pages.map((page) =>
    page.contentID === pageID
      ? { ...page, parentID: move.parentID, order: order.get(pageID) ?? page.order }
      : order.has(page.contentID)
        ? { ...page, order: order.get(page.contentID) ?? page.order }
        : page,
  )
}

/** Pages matching the text (title or slug) plus their ancestors, so matches stay in their place in the tree */
export function filterPages(pages: TreePage[], text: string): TreePage[] {
  const needle = text.trim().toLowerCase()
  if (!needle) return pages
  const byID = new Map(pages.map((page) => [page.contentID, page]))
  const keep = new Set<string>()
  for (const page of pages) {
    if (page.title.toLowerCase().includes(needle) || page.slug.toLowerCase().includes(needle)) {
      let current: TreePage | undefined = page
      while (current && !keep.has(current.contentID)) {
        keep.add(current.contentID)
        current = byID.get(current.parentID)
      }
    }
  }
  return pages.filter((page) => keep.has(page.contentID))
}
