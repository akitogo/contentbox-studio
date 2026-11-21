import { describe, expect, it } from 'vitest'
import { folderOf, mediaPath } from './media'

const ORIGIN = 'http://127.0.0.1:8589'

describe('mediaPath', () => {
  it('reads the path below the media root', () => {
    expect(mediaPath('/__media/sites/default/images/sea-view.jpg', ORIGIN)).toBe('sites/default/images/sea-view.jpg')
    expect(mediaPath('/__media/sea-view.jpg', ORIGIN)).toBe('sea-view.jpg')
  })

  it('decodes the segments and ignores query and hash', () => {
    expect(mediaPath('/__media/images/sea%20view.jpg?v=2#x', ORIGIN)).toBe('images/sea view.jpg')
    expect(mediaPath('/__media/%C3%BCber/a.png', ORIGIN)).toBe('über/a.png')
  })

  it('accepts full URLs of this site only', () => {
    expect(mediaPath(`${ORIGIN}/__media/images/a.png`, ORIGIN)).toBe('images/a.png')
    expect(mediaPath('https://cdn.example.com/__media/images/a.png', ORIGIN)).toBeNull()
  })

  it('returns null for other addresses', () => {
    expect(mediaPath(undefined, ORIGIN)).toBeNull()
    expect(mediaPath('', ORIGIN)).toBeNull()
    expect(mediaPath('/__media/', ORIGIN)).toBeNull()
    expect(mediaPath('/images/a.png', ORIGIN)).toBeNull()
    expect(mediaPath('/__media/bad%E0%A4%A.png', ORIGIN)).toBeNull()
  })
})

describe('folderOf', () => {
  it('drops the file name', () => {
    expect(folderOf('sites/default/images/sea-view.jpg')).toBe('sites/default/images')
    expect(folderOf('sea-view.jpg')).toBe('')
    expect(folderOf(null)).toBe('')
  })
})
