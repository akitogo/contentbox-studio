# Converting existing pages into blocks

Existing ContentBox content is hand-written HTML: in Studio it opens as one HTML block that only administrators can
edit. The conversion tool turns that HTML into real blocks, page by page, and refuses wherever it would lose
something. It needs the `STUDIO_CONVERT` permission (administrators); copying a site also needs ContentBox's
`SITES_ADMIN`.

The tool is **Convert** in Studio's header (`/cbstudio/convert`): pick the site and a profile, look at the dry run
(per item and section: which block, passes or differs, and why), select the items that are ready and convert them. Copy
the site from there too. Everything it does is also in the API (below).

There are two ways:

| | Same look | New look |
|---|---|---|
| Theme | Blocks that reproduce the old HTML (e.g. the old theme with a `blocks/` folder) | Another theme, e.g. a Tailwind theme with ready-made blocks |
| Check per section | The rendered block is the same markup (`compare: markup`) | No text, link or image of the old section is missing (`compare: content`) |
| Where | On the site itself, or on a copy | Only on a copy of the site: the original is never changed |

## 1. Copy the site (recommended, required for a new look)

`POST /cbstudio/api/sites/:site/copy` with `{ name, slug, domain, theme }` creates a new site with ContentBox's own
export and import: pages, blog entries, content store, categories, menus, site settings, custom fields and versions.
The original is only read. The copy

- answers to its own domain only (pattern `^https?://<domain>(:port)?(/|?|$)`), without the original's aliases;
- gets the chosen theme, and new ids for its translation groups (Studio's groups never span two sites);
- remembers its original (site setting `cbstudio_copiedFrom`), which allows converting it to a new look.

ContentBox serves the first site (by name) whose domain pattern matches a URL. If another site's pattern also matches
the new domain (e.g. a pattern `localhost` without anchors), the result says the copy is not reachable there yet:
change that site's pattern in the classic admin (Sites) or pick another domain. When the copy is done, switch the
domains over in the classic admin.

## 2. Write a profile

A profile says how old sections become blocks of one theme. It is needed once per site and is usually specific to
it, so it lives in neither theme: `modules_app/contentbox-custom/_convert/<name>/profile.json` (other modules can add
folders with `Profiles@contentbox-studio`'s `registerDirectory( directory, invocationPath )`).

```json
{
  "label": "Old site → Studio Starter",
  "theme": "studio-starter",
  "compare": "content",
  "rules": [
    {
      "block": "hero",
      "match": "section.intro",
      "fields": {
        "title": "h1",
        "text": "p.lead",
        "image": "img",
        "buttonLabel": "a.button",
        "button": "a.button",
        "tone": { "classes": { "intro--dark": "dark", "intro--light": "light" } }
      }
    },
    {
      "block": "steps",
      "match": "ol.steps",
      "fields": { "items": { "each": "li", "fields": { "title": "h3", "text": "div.text" } } }
    },
    { "block": "team", "reader": "team" }
  ]
}
```

- `theme`: the theme whose blocks the rules produce; it must be the site's active theme.
- `compare`: `markup` (default) or `content`, see the table above.
- `rules`: tried in order for each top-level element of a body; the first rule whose `match` (a CSS selector, jsoup
  syntax, e.g. `section.intro`, `div:has(h2.title)`) fits the element and whose fields can all be read wins.

### Fields

A field only needs a selector inside the section; how it is read follows from the field's type in the block's
`block.json`:

| Field type | Read as |
|---|---|
| `text`, `contentStore` | the element's text; markup inside it (`<em>`, `<br>`) is not convertible |
| `textarea` | text with `<br>` as line breaks |
| `richtext` | paragraphs, headings, lists, quotes, rules, bold, italic, underline, strike, code, sub/superscript, links; loose text becomes a paragraph |
| `number` | the text as a number |
| `boolean` | whether the selector finds something, or `{ "classes": { "wide": true } }` |
| `select` | `{ "classes": { "old-class": "option" } }`, an attribute or the text; must be one of the options |
| `link` | `href` and `target` of an `<a>` |
| `image` / `images` | `src`, `alt` (and `width`/`height`) of an `<img>`; all matches for `images` |
| `list` | `{ "each": "<item selector>", "fields": { ... } }`, read per item like a block |
| `html` | the element's inner HTML as it is |

Selector forms: `"h2"`, `"&"` or `""` for the section itself, `"img @alt"` or `"@data-id"` for an attribute, and
`{ "value": "dark" }` for a fixed value. `{ "select": "a.button", "ignore": "svg" }` leaves out elements the template
outputs itself (an icon in a button). Fields without a spec get their default. A missing element gives an empty
value.

When a section has markup its field cannot hold, the section stays an HTML block and the report says why: nothing is
dropped silently.

### Code readers

For sections a description cannot express, a rule names a reader: `readers/<name>.cfc` in the profile folder.

```cfml
component {
	// Return the block data, or nothing if this section is not this block
	function read( required element, required read ) {
		if ( !arguments.element.hasClass( "team" ) ) {
			return;
		}
		var people = [];
		for ( var card in arguments.read.selectAll( arguments.element, ".card" ) ) {
			people.append( {
				"name" : arguments.read.text( card.selectFirst( "h3" ) ),
				"photo": arguments.read.image( card.selectFirst( "img" ) ),
				"bio"  : arguments.read.richText( card.selectFirst( ".bio" ) )
			} );
		}
		return { "people": people };
	}
}
```

`element` is a jsoup element; `read` has the helpers `text`, `lines`, `richText`, `link`, `image`, `images`,
`classFrom( element, map )`, `select`, `selectAll` and `unconvertible( message )` (keep the section as HTML).

## 3. Dry run and convert

In Studio: the screen runs the dry run when you pick a site and a profile; expand an item for its sections and their
HTML. API:

- `GET /cbstudio/api/convert`: profiles (with their problems) and the themes a copy can use.
- `GET /cbstudio/api/sites/:site/convert?profile=<name>`: dry run over all pages, blog entries and content store
  items: per item whether it is ready, per section the block it became and whether it passed. With `&contentID=` one
  item, with each section's HTML and, where it differs, the two canonical forms (markup) or what is missing
  (content).
- `POST /cbstudio/api/sites/:site/convert` with `{ profile, contentIDs: [] }`: converts the items that are ready.

How a body is split: each top-level element and each widget call (`{{{...}}}`) between elements is a section.
`{{{ContentStore slug="..."}}}` becomes a content store block; other widget calls and sections no rule matches stay
HTML, neighbouring ones as one HTML block. A body is **ready** when every section passes and at least one became a
block. Converting saves a new version through Studio (undo: restore the previous version); its publish state stays.
Content that already has blocks is skipped.
