import type { PageStatus } from '../types'
import type { BadgeTone } from '../ui'

/** How a page's or entry's status looks: badge, and the dot on its icon where there is no room for the badge */
export const STATUS: Record<PageStatus, { label: string; tone: BadgeTone; dot: string }> = {
  published: { label: 'Published', tone: 'success', dot: 'bg-emerald-500' },
  draft: { label: 'Draft', tone: 'neutral', dot: 'bg-slate-300' },
  scheduled: { label: 'Scheduled', tone: 'warning', dot: 'bg-amber-500' },
  expired: { label: 'Expired', tone: 'danger', dot: 'bg-red-500' },
}
