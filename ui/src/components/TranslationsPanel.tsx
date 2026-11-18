import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { messageOf, useStudio } from '../studio'
import type { TranslationGroup, TreePage } from '../types'

/**
 * Details of a page in the tree: language and translation group
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
    const members = new Set(group?.members.map((member) => member.contentID) ?? [page.contentID])
    return candidates.filter((candidate) => !members.has(candidate.contentID)).sort((a, b) => a.slug.localeCompare(b.slug))
  }, [candidates, group, page.contentID])

  async function run(action: () => Promise<TranslationGroup>) {
    setError('')
    try {
      setGroup(await action())
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

  return (
    <aside className="studio-panel studio-side" aria-label={`Details of ${page.title}`}>
      <div className="studio-side__head">
        <h2>{page.title}</h2>
        <button type="button" onClick={onClose} aria-label="Close details">×</button>
      </div>
      <p className="studio-muted">/{page.slug}</p>
      <p>
        <Link to={`/content/${page.contentID}`}>Edit content</Link> · <a href={page.url} target="_blank" rel="noreferrer">View</a>
      </p>

      <h3>Language</h3>
      <form onSubmit={saveLanguage} className="studio-inline-form">
        <input
          value={language}
          onChange={(event) => setLanguage(event.target.value)}
          placeholder="e.g. de or en-GB"
          aria-label="Language code"
          disabled={!canEdit}
          size={10}
        />
        {canEdit && <button type="submit">Save</button>}
      </form>

      <h3>Translations</h3>
      {group && group.members.length > 1 ? (
        <ul className="studio-list">
          {group.members.map((member) => (
            <li key={member.contentID}>
              <span className="studio-badge studio-badge--language">{member.language || '?'}</span>{' '}
              {member.isCurrent ? (
                <strong>{member.title}</strong>
              ) : (
                <a href={member.url} target="_blank" rel="noreferrer">{member.title}</a>
              )}{' '}
              <small>{member.siteName}</small>
            </li>
          ))}
        </ul>
      ) : (
        <p className="studio-muted">Not linked to other languages.</p>
      )}
      {canEdit && group && group.members.length > 1 && (
        <button type="button" onClick={() => void run(() => api.delete<TranslationGroup>(`${base}/translations`))}>
          Remove from this group
        </button>
      )}

      {canEdit && (
        <form onSubmit={link} className="studio-stack">
          <h3>Link a translation</h3>
          {sites.length > 1 && (
            <select value={linkSiteID} onChange={(event) => setLinkSiteID(event.target.value)} aria-label="Site of the translation">
              {sites.map((site) => (
                <option key={site.siteID} value={site.siteID}>{site.name}</option>
              ))}
            </select>
          )}
          <select value={linkID} onChange={(event) => setLinkID(event.target.value)} aria-label="Page that is a translation">
            <option value="">Choose a page…</option>
            {linkable.map((candidate) => (
              <option key={candidate.contentID} value={candidate.contentID}>
                /{candidate.slug} {candidate.language ? `(${candidate.language})` : ''}
              </option>
            ))}
          </select>
          <button type="submit" disabled={!linkID}>Link</button>
        </form>
      )}
      {error && <p className="studio-error" role="alert">{error}</p>}
    </aside>
  )
}
