import { useEffect, useState } from 'react'
import type { ParsedBlock } from '../blocks/format'
import { messageOf, useStudio } from '../studio'
import type { VersionInfo } from '../types'

/**
 * Versions of the content; loading one puts its blocks into the editor (saving makes it the current version)
 */
export function VersionsPanel({
  contentID,
  currentVersion,
  onLoad,
  onClose,
}: {
  contentID: string
  currentVersion: number
  onLoad: (blocks: ParsedBlock[], version: number) => void
  onClose: () => void
}) {
  const { config, api } = useStudio()
  const [versions, setVersions] = useState<VersionInfo[] | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    api
      .get<VersionInfo[]>(`${config.studioApi}/content/${contentID}/versions`)
      .then(setVersions, (e: unknown) => setError(messageOf(e)))
  }, [api, config, contentID, currentVersion])

  async function load(version: VersionInfo) {
    try {
      const result = await api.get<{ version: number; blocks: ParsedBlock[] }>(
        `${config.studioApi}/content/${contentID}/versions/${version.versionID}`,
      )
      onLoad(result.blocks, result.version)
    } catch (e) {
      setError(messageOf(e))
    }
  }

  return (
    <aside className="studio-panel studio-versions" aria-label="Versions">
      <div className="studio-side__head">
        <h2>Versions</h2>
        <button type="button" onClick={onClose} aria-label="Close versions">×</button>
      </div>
      {error && <p className="studio-error" role="alert">{error}</p>}
      {!versions && !error && <p className="studio-muted">Loading…</p>}
      <ol className="studio-versions__list">
        {versions?.map((version) => (
          <li key={version.versionID}>
            <strong>Version {version.version}</strong> {version.isActive && <span className="studio-badge studio-badge--published">current</span>}
            <br />
            <small>
              {version.createdDate.replace('T', ' ')} · {version.author}
            </small>
            {version.changelog && <p className="studio-versions__note">{version.changelog}</p>}
            {!version.isActive && (
              <button type="button" onClick={() => void load(version)}>
                Load into editor
              </button>
            )}
          </li>
        ))}
      </ol>
    </aside>
  )
}
