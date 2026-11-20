import type { PageStatus } from '../types'

/** Filters of the blog list; category is a category id, "none" (no category) or "" (all) */
export interface BlogFilter {
  search: string
  status: PageStatus | ''
  category: string
}

export const NO_FILTER: BlogFilter = { search: '', status: '', category: '' }

/** Query string for GET /sites/:site/entries: only the filters that are set, the newest `max` entries */
export function entriesQuery(filter: BlogFilter, max: number): string {
  const params = new URLSearchParams()
  const search = filter.search.trim()
  if (search) params.set('search', search)
  if (filter.status) params.set('status', filter.status)
  if (filter.category) params.set('category', filter.category)
  params.set('max', String(max))
  return params.toString()
}

/** A date from the API (yyyy-mm-ddTHH:nn:ss, local time) as a short date, "" for none */
export function shortDate(value: string, locale?: string): string {
  if (!value) return ''
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString(locale, { year: 'numeric', month: 'short', day: 'numeric' })
}
