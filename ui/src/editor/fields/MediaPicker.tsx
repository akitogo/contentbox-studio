import { ChevronRight, FileText, Folder, Upload } from 'lucide-react'
import { useCallback, useEffect, useRef, useState, type ChangeEvent } from 'react'
import { folderOf, mediaPath } from '../../lib/media'
import { messageOf, useStudio } from '../../studio'
import type { MediaFile, MediaListing } from '../../types'
import { Alert, Badge, Button, cx, Dialog, Loading } from '../../ui'

/**
 * ContentBox's media library in a dialog: folders, files, upload. Opens in the folder of `current` (the image in
 * use, marked in the list) or of `near` (e.g. the last image of a gallery), else at the root.
 */
export function MediaPicker({
  imagesOnly = true,
  current,
  near,
  onSelect,
  onClose,
}: {
  imagesOnly?: boolean
  /** URL of the file in use */
  current?: string
  /** URL of a file whose folder to start in, when there is no `current` */
  near?: string
  onSelect: (file: MediaFile) => void
  onClose: () => void
}) {
  const { config, api } = useStudio()
  const [folder, setFolder] = useState('')
  const [listing, setListing] = useState<MediaListing | null>(null)
  const [error, setError] = useState('')
  const [uploading, setUploading] = useState(false)
  const fileInput = useRef<HTMLInputElement>(null)
  const list = useRef<HTMLUListElement>(null)
  const currentPath = mediaPath(current)
  // Where to start: fixed when the dialog opens
  const [startFolder] = useState(() => folderOf(currentPath ?? mediaPath(near)))

  const load = useCallback(
    async (path: string) => {
      setError('')
      try {
        setListing(await api.get<MediaListing>(`${config.studioApi}/media?folder=${encodeURIComponent(path)}`))
        setFolder(path)
        return true
      } catch (e) {
        setError(messageOf(e))
        return false
      }
    },
    [api, config],
  )

  // The start folder, or the root if it cannot be listed
  useEffect(() => {
    void load(startFolder).then((loaded) => {
      if (!loaded && startFolder) void load('')
    })
  }, [load, startFolder])

  // Bring the file in use into view when its folder is shown
  useEffect(() => {
    list.current?.querySelector('[aria-current="true"]')?.scrollIntoView({ block: 'nearest' })
  }, [listing])

  async function upload(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    if (!file) return
    const form = new FormData()
    form.append('file', file)
    form.append('folder', folder)
    setUploading(true)
    setError('')
    try {
      const stored = await api.upload<MediaFile>(`${config.studioApi}/media`, form)
      await load(folder)
      onSelect(stored)
    } catch (e) {
      setError(messageOf(e))
    } finally {
      setUploading(false)
      event.target.value = ''
    }
  }

  const files = listing?.files.filter((file) => !imagesOnly || file.isImage) ?? []
  const crumbs = folder ? folder.split('/') : []

  return (
    <Dialog
      title="Media library"
      size="lg"
      onClose={onClose}
      footer={
        <>
          <span className="mr-auto self-center text-xs text-slate-500">Images (JPG, PNG, GIF, WebP, AVIF) or PDF, up to 20 MB</span>
          <input ref={fileInput} type="file" accept={imagesOnly ? 'image/*' : 'image/*,application/pdf'} onChange={upload} hidden />
          <Button variant="primary" onClick={() => fileInput.current?.click()} disabled={uploading}>
            <Upload className="size-4" />
            {uploading ? 'Uploading…' : 'Upload'}
          </Button>
        </>
      }
    >
      {/* Stays at the top of the dialog's scrolling body (its 1rem padding: -top-4, -mt-4/pt-4) */}
      <nav className="sticky -top-4 z-10 -mx-5 -mt-4 mb-3 flex flex-wrap items-center gap-1 border-b border-slate-100 bg-white px-5 pt-4 pb-2 text-sm" aria-label="Folder">
        <button type="button" className="cursor-pointer rounded px-1.5 py-0.5 text-primary-600 hover:bg-slate-100" onClick={() => void load('')}>
          Media
        </button>
        {crumbs.map((crumb, index) => (
          <span key={index} className="flex items-center gap-1">
            <ChevronRight className="size-3.5 text-slate-400" />
            <button
              type="button"
              className="cursor-pointer rounded px-1.5 py-0.5 text-primary-600 hover:bg-slate-100"
              onClick={() => void load(crumbs.slice(0, index + 1).join('/'))}
            >
              {crumb}
            </button>
          </span>
        ))}
      </nav>

      {error && <Alert tone="danger" className="mb-3">{error}</Alert>}
      {!listing && !error && <Loading />}

      {listing && listing.folders.length > 0 && (
        <div className="mb-4 flex flex-wrap gap-2">
          {listing.folders.map((item) => (
            <Button key={item.path} size="sm" onClick={() => void load(item.path)}>
              <Folder className="size-3.5 text-slate-500" />
              {item.name}
            </Button>
          ))}
        </div>
      )}

      {listing && (
        <ul ref={list} className="grid grid-cols-[repeat(auto-fill,minmax(8.5rem,1fr))] gap-3">
          {files.map((file) => {
            const inUse = file.path === currentPath
            return (
              <li key={file.path}>
                <button
                  type="button"
                  onClick={() => onSelect(file)}
                  title={inUse ? `${file.name} (in use)` : file.name}
                  aria-current={inUse || undefined}
                  className={cx(
                    'group grid w-full cursor-pointer gap-1.5 rounded-lg border bg-white p-1.5 text-left hover:border-primary-400 hover:ring-2 hover:ring-primary-500/20',
                    inUse ? 'border-primary-500 ring-2 ring-primary-500/40' : 'border-slate-200',
                  )}
                >
                  <span className="grid aspect-[4/3] place-items-center overflow-hidden rounded-md bg-slate-100">
                    {file.isImage ? <img src={file.url} alt="" loading="lazy" className="size-full object-cover" /> : <FileText className="size-8 text-slate-400" />}
                  </span>
                  <span className="flex items-center gap-1 px-0.5 text-xs text-slate-600">
                    <span className="truncate">{file.name}</span>
                    {inUse && (
                      <Badge tone="primary" className="ml-auto shrink-0 px-1.5 py-0 text-[10px]">
                        In use
                      </Badge>
                    )}
                  </span>
                </button>
              </li>
            )
          })}
        </ul>
      )}
      {listing && !files.length && <p className="py-8 text-center text-sm text-slate-500">No files in this folder yet. Upload one.</p>}
    </Dialog>
  )
}
