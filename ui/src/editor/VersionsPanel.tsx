import { X } from 'lucide-react'
import { useEffect, useState } from 'react'
import type { ParsedBlock } from '../blocks/format'
import { messageOf, useStudio } from '../studio'
import type { VersionInfo } from '../types'
import { Alert, Badge, Button, IconButton, Loading } from '../ui'

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
    api.get<VersionInfo[]>(`${config.studioApi}/content/${contentID}/versions`).then(setVersions, (e: unknown) => setError(messageOf(e)))
  }, [api, config, contentID, currentVersion])

  async function load(version: VersionInfo) {
    try {
      const result = await api.get<{ version: number; blocks: ParsedBlock[] }>(`${config.studioApi}/content/${contentID}/versions/${version.versionID}`)
      onLoad(result.blocks, result.version)
    } catch (e) {
      setError(messageOf(e))
    }
  }

  return (
    <aside className="flex min-h-0 w-80 shrink-0 flex-col border-l border-slate-200 bg-white" aria-label="Versions">
      <div className="flex h-12 shrink-0 items-center justify-between border-b border-slate-200 px-4">
        <h2 className="text-sm font-semibold text-slate-900">Versions</h2>
        <IconButton label="Close versions" onClick={onClose}>
          <X className="size-4" />
        </IconButton>
      </div>
      <div className="min-h-0 flex-1 overflow-auto p-4">
        {error && <Alert tone="danger">{error}</Alert>}
        {!versions && !error && <Loading />}
        <ol className="relative grid gap-4 border-l border-slate-200 pl-4">
          {versions?.map((version) => (
            <li key={version.versionID} className="relative">
              <span className={`absolute top-1.5 -left-[21px] size-2.5 rounded-full ring-4 ring-white ${version.isActive ? 'bg-emerald-500' : 'bg-slate-300'}`} />
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium text-slate-900">Version {version.version}</span>
                {version.isActive && <Badge tone="success">current</Badge>}
              </div>
              <p className="text-xs text-slate-500">
                {version.createdDate.replace('T', ' ')} · {version.author}
              </p>
              {version.changelog && <p className="mt-1 text-sm text-slate-700">{version.changelog}</p>}
              {!version.isActive && (
                <Button size="sm" className="mt-2" onClick={() => void load(version)}>
                  Load into editor
                </Button>
              )}
            </li>
          ))}
        </ol>
      </div>
    </aside>
  )
}
