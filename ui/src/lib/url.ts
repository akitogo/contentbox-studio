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

/** A full URL with encoded characters shown readably ("https://example.com/de/über-uns"); unchanged if not decodable */
export function readableURL(url: string): string {
  try {
    return decodeURI(url)
  } catch {
    return url
  }
}
