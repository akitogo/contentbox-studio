import { LogOut } from 'lucide-react'
import { useContext, type ReactNode } from 'react'
import { Link } from 'react-router'
import { useStudio } from '../studio'
import { Button, buttonClass } from '../ui'
import { WorkspaceContext } from '../workspace/WorkspaceContext'

/** Top bar of every screen; children go in the middle */
export function Header({ children }: { children?: ReactNode }) {
  const { config, api, me } = useStudio()
  // In the workspace, leaving goes through its navigation (which asks about unsaved changes)
  const workspace = useContext(WorkspaceContext)

  async function logout() {
    try {
      await api.post(`${config.contentboxApi}/logout`)
    } finally {
      window.location.href = config.logoutUrl
    }
  }

  return (
    <header className="sticky top-0 z-40 flex h-14 shrink-0 items-center gap-4 border-b border-slate-200 bg-white px-4">
      <Link to="/" className="flex items-center gap-2 text-slate-900 no-underline hover:text-slate-900">
        <span className="grid size-7 place-items-center rounded-md bg-primary-600 text-xs font-bold text-white">CB</span>
        <span className="font-semibold">Studio</span>
        <span className="text-xs text-slate-400">{config.version}</span>
      </Link>
      <div className="flex min-w-0 flex-1 items-center gap-3">{children}</div>
      <div className="flex items-center gap-1">
        <div className="mr-2 hidden text-right leading-tight sm:block">
          <div className="text-sm font-medium text-slate-900">{me.name}</div>
          <div className="text-xs text-slate-500">{me.role}</div>
        </div>
        {me.permissions.convert && (
          <Link
            to="/convert"
            className={buttonClass('ghost', 'sm')}
            onClick={(event) => {
              if (!workspace) return
              event.preventDefault()
              workspace.goTo('/convert')
            }}
          >
            Convert
          </Link>
        )}
        <a href={config.adminUrl} className={buttonClass('ghost', 'sm')}>
          Classic admin
        </a>
        <Button variant="ghost" size="sm" onClick={() => void logout()}>
          <LogOut className="size-3.5" />
          Log out
        </Button>
      </div>
    </header>
  )
}
