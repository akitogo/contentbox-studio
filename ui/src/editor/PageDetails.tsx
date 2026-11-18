import { ExternalLink, Settings2 } from 'lucide-react'
import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { messageOf, useStudio } from '../studio'
import type { ContentDetails, TranslationGroup, TreePage } from '../types'
import { Alert, Badge, Button, Field, Input, Select } from '../ui'
import { useWorkspace } from '../workspace/WorkspaceContext'

const ADMIN_EDITORS: Record<ContentDetails['contentType'], string> = {
  page: 'pages/editor',
  entry: 'entries/editor',
  contentStore: 'contentStore/editor',
}

/**
 * Settings of the open content, shown in the editor's right column when no block is selected: address, language
 * and translation group, and a link to the other settings in the classic admin
 */
export function PageDetails({ content, canEdit }: { content: ContentDetails; canEdit: boolean }) {
  const { config, api, me, sites } = useStudio()
  const { reload, openPage } = useWorkspace()
  const [group, setGroup] = useState<TranslationGroup | null>(null)
  const [language, setLanguage] = useState('')
  const [linkSiteID, setLinkSiteID] = useState(content.siteID)
  const [candidates, setCandidates] = useState<TreePage[]>([])
  const [linkID, setLinkID] = useState('')
  const [error, setError] = useState('')
  const canChange = canEdit && me.permissions.siteTree
  const base = `${config.studioApi}/content/${content.contentID}`

  useEffect(() => {
    api.get<TranslationGroup>(`${base}/translations`).then(
      (loaded) => {
        setGroup(loaded)
        setLanguage(loaded.language)
      },
      (e: unknown) => setError(messageOf(e)),
    )
  }, [api, base])

  useEffect(() => {
    if (!canChange || !linkSiteID) return
    api
      .get<TreePage[]>(`${config.studioApi}/sites/${encodeURIComponent(linkSiteID)}/tree`)
      .then(setCandidates, (e: unknown) => setError(messageOf(e)))
  }, [api, config, linkSiteID, canChange])

  const linkable = useMemo(() => {
    const members = new Set([content.contentID, ...(group?.members.map((member) => member.contentID) ?? [])])
    return candidates.filter((candidate) => !members.has(candidate.contentID)).sort((a, b) => a.slug.localeCompare(b.slug))
  }, [candidates, group, content.contentID])

  /** Apply a change that returns the translation group, then refresh the tree (language badges) */
  async function change(action: () => Promise<TranslationGroup>) {
    setError('')
    try {
      const updated = await action()
      setGroup(updated)
      setLanguage(updated.language)
      setLinkID('')
      await reload()
    } catch (e) {
      setError(messageOf(e))
    }
  }

  function saveLanguage(event: FormEvent) {
    event.preventDefault()
    void change(() => api.put<TranslationGroup>(`${base}/language`, { language }))
  }

  function link(event: FormEvent) {
    event.preventDefault()
    if (linkID) void change(() => api.post<TranslationGroup>(`${base}/translations`, { translationID: linkID }))
  }

  const members = group?.members ?? []

  return (
    <div className="grid gap-5 p-4 text-sm">
      <div className="grid gap-1">
        <span className="text-xs font-medium tracking-wide text-slate-500 uppercase">Address</span>
        <a href={content.url} target="_blank" rel="noreferrer" className="flex items-center gap-1.5 font-mono text-xs break-all">
          {content.url}
          <ExternalLink className="size-3 shrink-0" />
        </a>
      </div>

      <form onSubmit={saveLanguage}>
        <Field label="Language" htmlFor="content-language" help="A code like de, en or en-GB, for hreflang links.">
          <div className="flex gap-2">
            <Input id="content-language" value={language} onChange={(event) => setLanguage(event.target.value)} placeholder="e.g. de" disabled={!canChange} />
            {canChange && (
              <Button type="submit" disabled={!group || language === group.language}>
                Save
              </Button>
            )}
          </div>
        </Field>
      </form>

      <div className="grid gap-2">
        <span className="text-sm font-medium text-slate-700">Translations</span>
        {members.length > 1 ? (
          <ul className="grid gap-1.5">
            {members.map((member) => (
              <li key={member.contentID} className="flex min-w-0 items-center gap-2">
                <Badge tone="primary" className="uppercase">
                  {member.language || '?'}
                </Badge>
                {member.isCurrent ? (
                  <span className="truncate font-medium text-slate-900">{member.title}</span>
                ) : (
                  <a
                    href={`${config.appBase}/content/${member.contentID}`}
                    className="truncate"
                    onClick={(event) => {
                      event.preventDefault()
                      openPage(member.contentID)
                    }}
                  >
                    {member.title}
                  </a>
                )}
                {member.siteID !== content.siteID && <span className="ml-auto truncate text-xs text-slate-400">{member.siteName}</span>}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-slate-500">Not linked to other languages.</p>
        )}
        {canChange && members.length > 1 && (
          <Button
            variant="danger"
            size="sm"
            className="justify-self-start"
            onClick={() => void change(() => api.delete<TranslationGroup>(`${base}/translations`))}
          >
            Remove from this group
          </Button>
        )}
      </div>

      {canChange && (
        <form onSubmit={link} className="grid gap-2 border-t border-slate-200 pt-4">
          <span className="text-sm font-medium text-slate-700">Link a translation</span>
          {sites.length > 1 && (
            <Select value={linkSiteID} onChange={(event) => setLinkSiteID(event.target.value)} aria-label="Site of the translation">
              {sites.map((site) => (
                <option key={site.siteID} value={site.siteID}>
                  {site.name}
                </option>
              ))}
            </Select>
          )}
          <Select value={linkID} onChange={(event) => setLinkID(event.target.value)} aria-label="Page that is a translation">
            <option value="">Choose a page…</option>
            {linkable.map((candidate) => (
              <option key={candidate.contentID} value={candidate.contentID}>
                /{candidate.slug} {candidate.language ? `(${candidate.language})` : ''}
              </option>
            ))}
          </Select>
          <Button type="submit" disabled={!linkID} className="justify-self-start">
            Link
          </Button>
        </form>
      )}

      {error && <Alert tone="danger">{error}</Alert>}

      <a
        href={`${config.adminUrl}/${ADMIN_EDITORS[content.contentType]}/contentID/${content.contentID}`}
        className="flex items-center gap-1.5 border-t border-slate-200 pt-4 text-slate-600 no-underline hover:text-slate-900"
      >
        <Settings2 className="size-4" />
        SEO, layout and other settings in the classic admin
      </a>
    </div>
  )
}
