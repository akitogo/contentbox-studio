# Block format, version 1

ContentBox Studio stores a page as a sequence of **blocks inside the normal content body**: every block is an HTML
comment with its data, followed by the HTML it renders to. ContentBox itself never needs to understand the
comments: the body is complete HTML, so versions, search, the REST API, exports and any renderer keep working, and
uninstalling Studio leaves plain HTML.

Implementations: `models/blocks/BlockFormat.cfc` (CFML) and `ui/src/blocks/format.ts` (TypeScript). Both are tested
against the same fixtures in `tests/fixtures/block-format/`.

## Example

```html
<!-- cb:block {"type":"heading","v":1,"id":"k2f9a","hash":"5d1f0c3e","data":{"text":"Rooms","level":"2"}} -->
<h2 class="cbs-heading">Rooms</h2>
<!-- /cb:block -->

<!-- cb:block {"type":"html","v":1,"id":"x81qe","hash":"0b9c4a17","data":{}} -->
<p>Any HTML</p>
<!-- /cb:block -->
```

## Markers

- Opening marker: `<!-- cb:block JSON -->`, closing marker: `<!-- /cb:block -->`.
- The **inner HTML** is everything between the two markers, minus one line break (`\n` or `\r\n`) directly after the
  opening marker and one directly before the closing marker.
- Blocks are not nested in version 1.
- Text outside blocks that is not only whitespace is kept (see Parsing).

## Envelope (the JSON in the opening marker)

| Key | Type | Meaning |
|---|---|---|
| `type` | string | Block type, `[A-Za-z][A-Za-z0-9_-]*`, e.g. `heading`, `textSection` |
| `v` | integer | Version of the block type's data (from its `block.json`), for later data migrations |
| `id` | string | Unique within the body, `[A-Za-z0-9_-]{1,32}`; stable across saves |
| `hash` | string | Hash of the inner HTML (see Hash); optional |
| `data` | object | Field values as defined by the block type. For `html` blocks `{}`: the inner HTML is the data |

Writers put the keys in this order. Readers accept any order and ignore unknown keys.

### Escaping

The JSON must not end the comment or trigger ContentBox's content renderers, so after encoding, writers replace,
everywhere in the JSON text:

| Text | Replacement | Why |
|---|---|---|
| `<` | `<` | no tags inside the comment |
| `>` | `>` | the comment cannot end early |
| `&` | `&` | no entities |
| `--` | `--` | `--` is not allowed inside HTML comments |
| `{{` | `{{` | ContentBox's widget renderer looks for `{{{` anywhere in the body |

These characters can only occur inside JSON strings, where the `\u` escapes decode back to the same text.

### Hash

Detects inner HTML that was changed outside Studio (REST API, database, importers). It is the Java `String.hashCode`
of the inner HTML as 8 lowercase hex digits (unsigned): `h = (31 * h + c) mod 2^32` over the UTF-16 code units `c`.
It is a change detector, not a security feature.

## Serializing

`<!-- cb:block JSON -->` + `\n` + inner HTML + `\n` + `<!-- /cb:block -->`, blocks separated by `\n\n`, no
trailing line break. The server renders the inner HTML on save (block type templates), so the stored body is always
complete.

Before writing, marker-like comments inside the inner HTML are renamed so they cannot nest: `<!--` followed by
optional whitespace, an optional `/` and `cb:block` becomes the same text with `cb-block` (regular expression
`<!--(\s*/?)cb:block` → `<!--$1cb-block`). They are comments, so the page does not change. This matters for legacy
content that contains broken markers: without it, every save would wrap them again. The hash is computed on the
inner HTML as written.

## Parsing

The result is a list of blocks with `type`, `v`, `id`, `data`, `html` (the inner HTML) and `status`:

| Status | When | Data |
|---|---|---|
| `ok` | well-formed block, hash matches or is missing | from the envelope |
| `modified` | hash does not match the inner HTML | from the envelope; the inner HTML wins on display |
| `invalid` | the envelope is not valid JSON or misses `type`/`id` | type `html`, inner HTML as content |
| `legacy` | content outside any block | type `html`, the text as content |

Rules, all lossless:

1. A body without markers is one `legacy` block (none if the body is empty or only whitespace).
2. Text between, before or after blocks that is not only whitespace becomes a `legacy` block in its place.
3. An opening marker without a closing marker, or a second opening marker before the closing one, ends parsing:
   everything from that opening marker to the end becomes one `legacy` block.
4. For `html` blocks, `data.html` is set to the inner HTML. Writers drop it again.
5. Generated ids for `legacy` and `invalid` blocks: `legacy-1`, `legacy-2`, ... in body order.

## Output

On the public site Studio removes the markers from the rendered page (`cb_onContentRendering`), so only the block
HTML is delivered. Without Studio the comments stay in the HTML, which browsers ignore.
