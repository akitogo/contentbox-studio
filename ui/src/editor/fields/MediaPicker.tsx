import { ChevronRight, FileText, Folder, Upload } from 'lucide-react'
import { useCallback, useEffect, useRef, useState, type ChangeEvent } from 'react'
import { messageOf, useStudio } from '../../studio'
import type { MediaFile, MediaListing } from '../../types'
import { Alert, Button, Dialog, Loading } from '../../ui'

/**
 * ContentBox's media library in a dialog: folders, files, upload
 */
export function MediaPicker({
  imagesOnly = true,
  onSelect,
  onClose,
}: {
  imagesOnly?: boolean
  onSelect: (file: MediaFile) => void
  onClose: () => void
}) {
  const { config, api } = useStudio()
  const [folder, setFolder] = useState('')
  const [listing, setListing] = useState<MediaListing | null>(null)
  const [error, setError] = useState('')
  const [uploading, setUploading] = useState(false)
  const fileInput = useRef<HTMLInputElement>(null)

  const load = useCallback(
    async (path: string) => {
      setError('')
      try {
        setListing(await api.get<MediaListing>(`${config.studioApi}/media?folder=${encodeURIComponent(path)}`))
        setFolder(path)
      } catch (e) {
        setError(messageOf(e))
      }
    },
    [api, config],
  )

  useEffect(() => {
    void load('')
  }, [load])

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
      <nav className="mb-3 flex flex-wrap items-center gap-1 text-sm" aria-label="Folder">
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
        <ul className="grid grid-cols-[repeat(auto-fill,minmax(8.5rem,1fr))] gap-3">
          {files.map((file) => (
            <li key={file.path}>
              <button
                type="button"
                onClick={() => onSelect(file)}
                title={file.name}
                className="group grid w-full cursor-pointer gap-1.5 rounded-lg border border-slate-200 bg-white p-1.5 text-left hover:border-primary-400 hover:ring-2 hover:ring-primary-500/20"
              >
                <span className="grid aspect-[4/3] place-items-center overflow-hidden rounded-md bg-slate-100">
                  {file.isImage ? <img src={file.url} alt="" loading="lazy" className="size-full object-cover" /> : <FileText className="size-8 text-slate-400" />}
                </span>
                <span className="truncate px-0.5 text-xs text-slate-600">{file.name}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
      {listing && !files.length && <p className="py-8 text-center text-sm text-slate-500">No files in this folder yet. Upload one.</p>}
    </Dialog>
  )
}
