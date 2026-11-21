/**
 * What /cbstudio shows in the editor area before content is open: it opens the site's start content (the page or entry
 * last edited there, else the home page, see lib/start.ts). Only a site without pages stays here, with a way to
 * create the first one.
 */
import { FileText, Plus } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router'
import { NewPageDialog } from '../components/NewPageDialog'
import { rememberedContent, startContent } from '../lib/start'
import { Button, Loading } from '../ui'
import { useWorkspace } from './WorkspaceContext'

export function StartPage() {
  const { site, pages, loading, loadError } = useWorkspace()
  const navigate = useNavigate()
  const [creating, setCreating] = useState(false)
  const target = site && !loading && !loadError ? startContent(site, pages, rememberedContent(site.siteID)) : null

  useEffect(() => {
    if (target) navigate(`/content/${target}`, { replace: true })
  }, [target, navigate])

  if (!site || loadError) return null
  if (loading || target) {
    return (
      <div className="grid h-full place-items-center">
        <Loading />
      </div>
    )
  }
  return (
    <div className="grid h-full place-items-center bg-slate-50 p-6">
      <div className="max-w-sm text-center">
        <FileText className="mx-auto size-8 text-slate-300" aria-hidden />
        <h2 className="mt-3 text-base font-semibold text-slate-900">No pages yet</h2>
        <p className="mt-1 text-sm text-slate-500">
          Create the first page of {site.name}
          {site.isBlogEnabled ? ', or open a blog entry in the column on the left' : ''}.
        </p>
        <Button variant="primary" className="mt-5" onClick={() => setCreating(true)}>
          <Plus className="size-4" />
          New page
        </Button>
      </div>
      {creating && <NewPageDialog site={site} pages={pages} onClose={() => setCreating(false)} />}
    </div>
  )
}
