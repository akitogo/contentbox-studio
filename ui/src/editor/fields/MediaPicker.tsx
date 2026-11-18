import { useCallback, useEffect, useState, type ChangeEvent } from 'react'
import { messageOf, useStudio } from '../../studio'
import type { MediaFile, MediaListing } from '../../types'

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

  return (
    <div className="studio-dialog" role="dialog" aria-modal="true" aria-label="Media library">
      <div className="studio-dialog__box">
        <div className="studio-dialog__head">
          <h2>Media library</h2>
          <button type="button" onClick={onClose} aria-label="Close">×</button>
        </div>
        <p className="studio-muted">/{folder}</p>
        <div className="studio-toolbar">
          {folder && <button type="button" onClick={() => void load(listing?.parent ?? '')}>↑ Up</button>}
          {listing?.folders.map((item) => (
            <button key={item.path} type="button" onClick={() => void load(item.path)}>📁 {item.name}</button>
          ))}
          <label className="studio-upload">
            {uploading ? 'Uploading…' : 'Upload'}
            <input type="file" accept={imagesOnly ? 'image/*' : 'image/*,application/pdf'} onChange={upload} disabled={uploading} hidden />
          </label>
        </div>
        {error && <p className="studio-error" role="alert">{error}</p>}
        <ul className="studio-media-grid">
          {files.map((file) => (
            <li key={file.path}>
              <button type="button" onClick={() => onSelect(file)} title={file.name}>
                {file.isImage ? <img src={file.url} alt="" loading="lazy" /> : <span className="studio-media-grid__file">PDF</span>}
                <span>{file.name}</span>
              </button>
            </li>
          ))}
        </ul>
        {listing && !files.length && <p className="studio-muted">No files in this folder.</p>}
      </div>
    </div>
  )
}
