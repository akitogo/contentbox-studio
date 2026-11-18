import { readdirSync, readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { hashHtml, neutralizeMarkers, parseBody, serializeBody, type ParsedBlock } from './format'

// Shared with the CFML implementation (tests/specs/unit/BlockFormatTest.cfc)
const fixtureDir = new URL('../../../tests/fixtures/block-format/', import.meta.url)

interface Fixture {
  description: string
  body: string
  blocks: ParsedBlock[]
  serialized?: string
}

const fixtures = readdirSync(fixtureDir)
  .filter((file) => file.endsWith('.json'))
  .sort()
  .map((file) => ({ file, ...(JSON.parse(readFileSync(new URL(file, fixtureDir), 'utf8')) as Fixture) }))

const toWrite = (blocks: ParsedBlock[]) =>
  blocks.map(({ type, v, id, data, html }) => ({ type, v, id, data, html }))

describe('block format fixtures', () => {
  it('finds the fixtures', () => {
    expect(fixtures.length).toBeGreaterThan(10)
  })

  for (const fixture of fixtures) {
    describe(`${fixture.file}: ${fixture.description}`, () => {
      it('parses', () => {
        expect(parseBody(fixture.body)).toEqual(fixture.blocks)
      })

      if (fixture.serialized !== undefined) {
        it('serializes the parsed blocks', () => {
          expect(serializeBody(toWrite(fixture.blocks))).toBe(fixture.serialized)
        })
      }

      it('round-trips: parsing the serialized blocks gives the same content', () => {
        const again = parseBody(serializeBody(toWrite(fixture.blocks)))
        // Marker-like comments inside block HTML are renamed on write (docs/block-format.md, Serializing)
        const written = (html: string, type: string, data: Record<string, unknown>) =>
          type === 'html' ? { ...data, html: neutralizeMarkers(html) } : data
        expect(again.map(({ type, v, data, html }) => ({ type, v, data, html }))).toEqual(
          fixture.blocks.map(({ type, v, data, html }) => ({
            type,
            v,
            data: written(html, type, data),
            html: neutralizeMarkers(html),
          })),
        )
        expect(again.every((block) => block.status === 'ok')).toBe(true)
      })
    })
  }
})

describe('hashHtml', () => {
  it('matches Java String.hashCode as unsigned hex', () => {
    // "hello".hashCode() == 99162322 == 0x05e918d2
    expect(hashHtml('hello')).toBe('05e918d2')
    expect(hashHtml('')).toBe('00000000')
  })
})
