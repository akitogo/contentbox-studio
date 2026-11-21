import { useEffect, type ReactNode } from 'react'
import { useEditorContext } from './EditorContext'

/** Minimal canvas styles, before the theme's and without specificity: any theme rule (e.g. its editor.css) wins */
const CANVAS_BASE = ':where(body) { margin: 0; background: #fff; }'

/**
 * Puck's iframe override: puts the theme's stylesheets into the canvas, so blocks look like on the site.
 * Studio's own styles are not synced into the canvas (iframe.syncHostStyles = false).
 */
export function CanvasStyles({ children, document: frame }: { children: ReactNode; document?: Document }) {
  const { stylesheets } = useEditorContext()

  useEffect(() => {
    if (!frame) return
    const base = frame.createElement('style')
    base.textContent = CANVAS_BASE
    frame.head.appendChild(base)
    const added: HTMLElement[] = [base]
    for (const href of stylesheets) {
      const link = frame.createElement('link')
      link.rel = 'stylesheet'
      link.href = href
      frame.head.appendChild(link)
      added.push(link)
    }
    return () => added.forEach((node) => node.remove())
  }, [frame, stylesheets])

  return <>{children}</>
}
