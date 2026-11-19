# Blocks in themes

A theme defines its own block types in a `blocks/` folder, one subfolder per type. Studio finds them in the site's
active theme; a theme block with the same name as a core block replaces it (except `html`).

```
mytheme/
└── blocks/
    └── roomTeaser/
        ├── block.json    what the editor shows and which fields the block has
        └── render.cfm    the HTML, rendered on the server when the page is saved
```

After adding or changing a block type, reinit the application (block types are cached per theme).

## block.json

```json
{
  "label": "Room teaser",
  "description": "A room with photo, text and a booking link",
  "icon": "bed",
  "category": "sections",
  "version": 1,
  "fields": [
    { "name": "title", "type": "text", "label": "Title", "required": true, "maxLength": 80 },
    { "name": "photo", "type": "image", "label": "Photo", "required": true },
    { "name": "text", "type": "richtext", "label": "Text" },
    { "name": "link", "type": "link", "label": "Booking link" },
    {
      "name": "layout",
      "type": "select",
      "label": "Layout",
      "default": "left",
      "options": [ { "value": "left", "label": "Photo left" }, { "value": "right", "label": "Photo right" } ]
    }
  ]
}
```

| Key | Default | Meaning |
|---|---|---|
| `name` | folder name | Block type, `[A-Za-z][A-Za-z0-9_-]*`; stored in every block of this type |
| `label`, `description`, `icon`, `category` | name, "", `block`, `other` | Shown in the editor |
| `version` | 1 | Raise it when the meaning of the data changes, so old blocks can be migrated |
| `fields` | `[]` | See below |

### Fields

Every field has `name` (`[A-Za-z][A-Za-z0-9_]*`), `type`, and optionally `label`, `help`, `required`, `default` and
`when`.

`when` shows a field only for certain values of other fields of the same block (or list item), which must be
`select` or `boolean` fields: `"when": { "layout": [ "card", "box" ], "boxed": [ true ] }` shows the field when
`layout` is `card` or `box` and `boxed` is on. A hidden field keeps its value and is not required.

| Type | Value in `args.data` | Extra keys |
|---|---|---|
| `text` | string, one line | `maxLength` |
| `textarea` | string with `\n` line breaks | `maxLength` |
| `richtext` | rich text document (render with `args.studio.richText()`) | |
| `number` | number, or `""` if empty | `min`, `max` |
| `boolean` | `true` / `false` | |
| `select` | one of the option values | `options`: strings or `{ value, label }` |
| `link` | `{ href, target }`, `href` already checked (http, https, mailto, tel, relative, `page:[slug]` ...) | |
| `image` | `{ src, alt }`, plus `width`/`height` if known | |
| `images` | array of images | `maxItems` |
| `list` | array of structs, each with the sub-fields | `fields`, `maxItems` |
| `contentStore` | slug of a content store item | |
| `html` | raw HTML string; needs the `STUDIO_HTML_BLOCKS` permission to change | |

Data is normalized against these definitions before rendering: unknown keys are dropped, missing ones get their
default, unsafe URLs are removed. Templates can rely on every field being present with the right type.

## render.cfm

```cfm
<cfoutput>
<section class="room room--#args.data.layout#">
	<img src="#args.studio.src( args.data.photo.src )#" alt="#args.studio.attr( args.data.photo.alt )#">
	<div class="room__body">
		<h2>#args.studio.esc( args.data.title )#</h2>
		#args.studio.richText( args.data.text )#
		<cfif len( args.data.link.href )>
			<a class="room__link"#args.studio.linkAttrs( args.data.link )#>Book now</a>
		</cfif>
	</div>
</section>
</cfoutput>
```

The template gets `args.data` (the fields), `args.block` (`{ id, type }`), `args.site` and `args.studio`, the helper
every value must go through:

| Helper | For |
|---|---|
| `esc( text )` | text in HTML |
| `attr( text )` | text in a double-quoted attribute |
| `nl2br( text )` | `textarea` values |
| `richText( doc )` | `richtext` values |
| `src( url )` | `image` URLs in `src=""` |
| `linkAttrs( link )` | `link` values: ` href="..."` plus `target`/`rel` for new windows |
| `contentStore( slug )` | `contentStore` values: the item stays live, ContentBox renders it on every page view |

Rules:

- Output field values only through the helper. Besides HTML escaping it defuses ContentBox's own syntax
  (`{{{Widget}}}`, `page:[slug]`) in text, so editors cannot trigger widgets by typing.
- Use the `local` scope for your own variables (`<cfset local.x = ...>`, `<cfloop ... index="local.item">`):
  templates run inside a shared object, and unscoped variables would leak between requests on Adobe ColdFusion.
- Values of `select` fields are always one of the options, so they can go into class names directly.
- The template runs when the page is saved, not on every view. After changing a template, re-render the pages
  that use it.
- Editing in place: in the editor canvas, text that a template outputs unchanged from a `text` or `textarea` field
  through `esc()` or `nl2br()` can be clicked and edited directly. Text the template changes first (`trim()`,
  splitting into words, ...) is edited in the fields panel; so are values that two fields share.

## Styles

- Blocks are styled by the theme's normal CSS. The editor canvas loads the stylesheets of the site's home page, so it
  shows blocks the way the site does.
- `blocks/editor.css` in the theme is loaded in the canvas only, after the theme's stylesheets: for adjustments
  that only the editor needs (e.g. spacing between blocks, or content that scripts would normally reveal).
- The core blocks (`cbs-*` classes) come with base styles (`includes/blocks.css` of the module). All its selectors
  use `:where()`, so they have no specificity and any theme rule overrides them. Accent color: `--cbs-accent`, else
  Bootstrap's `--bs-primary`. Turn the file off with the module setting `coreBlockStyles = false`.

## Blocks from modules

A ColdBox module can add block types too, from its `onLoad()` or by listening to `cbstudio_onBlockRegistration`
(data: `{ registry }`):

```js
function onLoad(){
	wirebox.getInstance( "BlockRegistry@contentbox-studio" )
		.registerDirectory( modulePath & "/blocks", "/mymodule/blocks" );
}
```

The second argument is the path to include the templates with (the module's class mapping plus `/blocks`).
Theme blocks override module blocks with the same name, module blocks override core blocks.
