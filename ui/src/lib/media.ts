/** ContentBox delivers the media library at /__media/<path> */
const MEDIA_PREFIX = '/__media/'

/**
 * The path below the media root of a media library URL ("/__media/images/rooms/sea%20view.jpg" →
 * "images/rooms/sea view.jpg"), also from a full URL on this site; null for anything else
 */
export function mediaPath(url: string | undefined, origin = globalThis.location?.origin ?? 'http://localhost'): string | null {
  if (!url) return null
  let parsed: URL
  try {
    parsed = new URL(url, origin)
  } catch {
    return null
  }
  if (parsed.origin !== new URL(origin).origin || !parsed.pathname.startsWith(MEDIA_PREFIX)) return null
  try {
    const segments = parsed.pathname.slice(MEDIA_PREFIX.length).split('/').filter(Boolean).map(decodeURIComponent)
    return segments.length ? segments.join('/') : null
  } catch {
    return null
  }
}

/** The folder of a path below the media root ("" for the root) */
export function folderOf(path: string | null): string {
  if (!path) return ''
  const slash = path.lastIndexOf('/')
  return slash < 0 ? '' : path.slice(0, slash)
}
