import { ExternalLink, Pencil, X } from 'lucide-react'
import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { messageOf, useStudio } from '../studio'
import type { TranslationGroup, TreePage } from '../types'
import { Alert, Badge, Button, buttonClass, Card, Field, IconButton, Input, Select } from '../ui'

/**
 * Details of the page selected in the tree: actions, publishing, language and translation group
 */
export function TranslationsPanel({
  page,
  onChanged,
  onClose,
}: {
  page: TreePage
  onChanged: () => Promise<void> | void
  onClose: () => void
}) {
  const { config, api, me, sites } = useStudio()
  const [group, setGroup] = useState<TranslationGroup | null>(null)
  const [language, setLanguage] = useState(page.language)
  const [linkSiteID, setLinkSiteID] = useState(sites[0]?.siteID ?? '')
  const [candidates, setCandidates] = useState<TreePage[]>([])
  const [linkID, setLinkID] = useState('')
  const [error, setError] = useState('')
  const canEdit = me.permissions.siteTree
  const base = `${config.studioApi}/content/${page.contentID}`

  useEffect(() => {
    api.get<TranslationGroup>(`${base}/translations`).then(setGroup, (e: unknown) => setError(messageOf(e)))
  }, [api, base])

  useEffect(() => {
    if (!linkSiteID) return
    api
      .get<TreePage[]>(`${config.studioApi}/sites/${encodeURIComponent(linkSiteID)}/tree`)
      .then(setCandidates, (e: unknown) => setError(messageOf(e)))
  }, [api, config, linkSiteID])

  const linkable = useMemo(() => {
    const members = new Set([page.contentID, ...(group?.members.map((member) => member.contentID) ?? [])])
    return candidates.filter((candidate) => !members.has(candidate.contentID)).sort((a, b) => a.slug.localeCompare(b.slug))
  }, [candidates, group, page.contentID])

  /** Run a change, keep a returned translation group, reload the tree */
  async function run(action: () => Promise<unknown>) {
    setError('')
    try {
      const result = await action()
      if (result && typeof result === 'object' && 'members' in result) setGroup(result as TranslationGroup)
      await onChanged()
    } catch (e) {
      setError(messageOf(e))
    }
  }

  function saveLanguage(event: FormEvent) {
    event.preventDefault()
    void run(() => api.put<TranslationGroup>(`${base}/language`, { language }))
  }

  function link(event: FormEvent) {
    event.preventDefault()
    if (linkID) void run(() => api.post<TranslationGroup>(`${base}/translations`, { translationID: linkID }))
  }

  const members = group?.members ?? []

  return (
    <aside aria-label={`Details of ${page.title}`} className="lg:sticky lg:top-20 lg:self-start">
      <Card>
        <div className="flex items-start justify-between gap-2 border-b border-slate-200 px-4 py-3">
          <div className="min-w-0">
            <h2 className="truncate text-base font-semibold text-slate-900">{page.title}</h2>
            <p className="truncate font-mono text-xs text-slate-500">/{page.slug}</p>
          </div>
          <IconButton label="Close details" onClick={onClose}>
            <X className="size-4" />
          </IconButton>
        </div>

        <div className="grid gap-5 px-4 py-4">
          <div className="flex flex-wrap gap-2">
            <Link to={`/content/${page.contentID}`} className={buttonClass('primary', 'sm')}>
              <Pencil className="size-3.5" />
              Edit content
            </Link>
            <a href={page.url} target="_blank" rel="noreferrer" className={buttonClass('secondary', 'sm')}>
              <ExternalLink className="size-3.5" />
              View
            </a>
            <Button
              size="sm"
              onClick={() => void run(() => api.put(`${base}/status`, { isPublished: !page.isPublished }))}
            >
              {page.isPublished ? 'Unpublish' : 'Publish'}
            </Button>
          </div>

          <form onSubmit={saveLanguage}>
            <Field label="Language" htmlFor="page-language" help="A code like de, en or en-GB. Used for hreflang links.">
              <div className="flex gap-2">
                <Input
                  id="page-language"
                  value={language}
                  onChange={(event) => setLanguage(event.target.value)}
                  placeholder="e.g. de"
                  disabled={!canEdit}
                />
                {canEdit && (
                  <Button type="submit" disabled={language === page.language}>
                    Save
                  </Button>
                )}
              </div>
            </Field>
          </form>

          <div className="grid gap-2">
            <h3 className="text-sm font-medium text-slate-700">Translations</h3>
            {members.length > 1 ? (
              <ul className="grid gap-1.5">
                {members.map((member) => (
                  <li key={member.contentID} className="flex items-center gap-2 text-sm">
                    <Badge tone="primary" className="uppercase">
                      {member.language || '?'}
                    </Badge>
                    {member.isCurrent ? (
                      <span className="font-medium text-slate-900">{member.title}</span>
                    ) : (
                      <a href={member.url} target="_blank" rel="noreferrer" className="truncate">
                        {member.title}
                      </a>
                    )}
                    <span className="ml-auto truncate text-xs text-slate-400">{member.siteName}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-slate-500">Not linked to other languages.</p>
            )}
            {canEdit && members.length > 1 && (
              <Button variant="danger" size="sm" className="justify-self-start" onClick={() => void run(() => api.delete<TranslationGroup>(`${base}/translations`))}>
                Remove from this group
              </Button>
            )}
          </div>

          {canEdit && (
            <form onSubmit={link} className="grid gap-2 border-t border-slate-200 pt-4">
              <h3 className="text-sm font-medium text-slate-700">Link a translation</h3>
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
        </div>
      </Card>
    </aside>
  )
}
