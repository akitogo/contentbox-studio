/** A URL from the site's root for display ("/blog/post"), without protocol and domain; anything else unchanged */
export function urlPath(url: string): string {
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return url
  }
  let path = parsed.pathname
  try {
    path = decodeURI(path)
  } catch {
    // keep the encoded form
  }
  return path + parsed.search + parsed.hash
}
