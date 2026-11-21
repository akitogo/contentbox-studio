import { describe, expect, it } from 'vitest'
import type { TreePage } from '../types'
import { applyMove, buildTree, childrenOf, filterPages, isWithin, moveFor, moveToRootEnd } from './tree'

function page(contentID: string, parentID = '', order = 0, title = contentID): TreePage {
  return {
    contentID,
    parentID,
    title,
    slug: contentID,
    order,
    status: 'published',
    isPublished: true,
    publishedDate: '',
    expireDate: '',
    showInMenu: true,
    hasBlocks: false,
    language: '',
    translationGroup: '',
    url: `/${contentID}`,
  }
}

// home, about (team, jobs), contact
const pages = [
  page('home', '', 1),
  page('about', '', 2),
  page('team', 'about', 1),
  page('jobs', 'about', 2),
  page('contact', '', 3),
]

const ids = (list: TreePage[]) => list.map((item) => item.contentID)

describe('buildTree', () => {
  it('nests pages by parent in order, then by title', () => {
    const tree = buildTree([page('b', '', 0, 'B'), page('a', '', 0, 'A'), page('c', 'a', 0)])
    expect(tree.map((node) => node.page.contentID)).toEqual(['a', 'b'])
    expect(tree[0]?.children[0]?.page.contentID).toBe('c')
    expect(tree[0]?.children[0]?.depth).toBe(1)
  })

  it('shows pages whose parent is missing at the root', () => {
    expect(buildTree([page('orphan', 'gone')]).map((node) => node.page.contentID)).toEqual(['orphan'])
  })
})

describe('moveFor', () => {
  it('moves before and after a sibling', () => {
    expect(moveFor(pages, 'contact', 'home', 'before')).toEqual({ parentID: '', index: 0 })
    expect(moveFor(pages, 'home', 'contact', 'after')).toEqual({ parentID: '', index: 2 })
  })

  it('moves inside a page as its last child', () => {
    expect(moveFor(pages, 'contact', 'about', 'inside')).toEqual({ parentID: 'about', index: 2 })
  })

  it('moves next to a page under another parent', () => {
    expect(moveFor(pages, 'contact', 'team', 'after')).toEqual({ parentID: 'about', index: 1 })
  })

  it('moves inside a page as its first child', () => {
    expect(moveFor(pages, 'contact', 'about', 'first')).toEqual({ parentID: 'about', index: 0 })
    expect(moveFor(pages, 'jobs', 'about', 'first')).toEqual({ parentID: 'about', index: 0 })
  })

  it('ignores drops that leave the page where it is', () => {
    expect(moveFor(pages, 'about', 'home', 'after')).toBeNull()
    expect(moveFor(pages, 'about', 'contact', 'before')).toBeNull()
    expect(moveFor(pages, 'jobs', 'about', 'inside')).toBeNull()
    expect(moveFor(pages, 'team', 'about', 'first')).toBeNull()
  })

  it('moves to the end of the top level', () => {
    expect(moveToRootEnd(pages, 'team')).toEqual({ parentID: '', index: 3 })
    expect(moveToRootEnd(pages, 'home')).toEqual({ parentID: '', index: 2 })
    expect(moveToRootEnd(pages, 'contact')).toBeNull()
  })

  it('refuses drops onto the page itself or into its subtree', () => {
    expect(moveFor(pages, 'about', 'about', 'inside')).toBeNull()
    expect(moveFor(pages, 'about', 'team', 'inside')).toBeNull()
    expect(moveFor(pages, 'about', 'jobs', 'before')).toBeNull()
  })
})


describe('applyMove', () => {
  it('changes the parent and renumbers the new siblings', () => {
    const moved = applyMove(pages, 'contact', { parentID: 'about', index: 1 })
    expect(ids(childrenOf(moved, 'about'))).toEqual(['team', 'contact', 'jobs'])
    expect(ids(childrenOf(moved, ''))).toEqual(['home', 'about'])
  })
})

describe('isWithin and filterPages', () => {
  it('knows subtrees', () => {
    expect(isWithin(pages, 'team', 'about')).toBe(true)
    expect(isWithin(pages, 'about', 'team')).toBe(false)
  })

  it('keeps matches with their ancestors', () => {
    expect(ids(filterPages(pages, 'JOB'))).toEqual(['about', 'jobs'])
    expect(filterPages(pages, ' ')).toHaveLength(pages.length)
  })
})
