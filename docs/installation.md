# Installing, upgrading and removing ContentBox Studio

## Requirements

| | Supported | Tested in CI |
|---|---|---|
| ContentBox | 7 | `development` branch of ContentBox 7 |
| Engine | BoxLang 1 (with the CFML compatibility module), Adobe ColdFusion 2023 and 2025 | BoxLang 1, Adobe 2023, Adobe 2025 |
| Database | what ContentBox 7 supports | MySQL (CI), PostgreSQL 17 (development) |
| Browser for editors | current Chrome, Edge, Firefox, Safari | |

Lucee is not supported, like in ContentBox 7. Studio needs no database tables of its own and no Node.js on the
server: the editor is shipped built (`dist/`).

## Install

### From ForgeBox

In the root of the ContentBox site:

```bash
box install contentbox-studio
```

### From a release zip

Download `contentbox-studio-<version>.zip` from the
[GitHub releases](https://github.com/akitogo/contentbox-studio/releases) and unpack it into
`modules_app/contentbox-studio` of the site.

### From git (development)

```bash
git clone https://github.com/akitogo/contentbox-studio.git modules_app/contentbox-studio
cd modules_app/contentbox-studio/ui && npm ci && npm run build
```

The built editor (`dist/`) is not in git, so a clone needs the build step (Node.js 22.12 or newer).

### Then

1. Reinit the site (restart it, or `?fwreinit=<your reinit password>`).
2. Studio creates its permissions on the first start and grants them to the default roles (see the
   [readme](../readme.md#permissions)). Existing permissions are never changed, so whatever you set up later in the
   classic admin is kept.
3. Log in to the classic admin. **Content → Studio** in its menu (or `/cbstudio`) opens Studio.

Studio works with any theme: pages are built from Studio's core blocks (text, heading, image, gallery, quote, button,
content store item, HTML). Blocks that fit the theme's design are added in the theme, see
[Blocks in themes](theme-blocks.md).

## Configure

Optional, in `config/ColdBox.cfc` of the site:

```js
moduleSettings = {
	"contentbox-studio" : {
		// Base styles of the core blocks on public pages and in the editor (theme rules always win)
		coreBlockStyles : true,
		// hreflang links for translated pages and entries
		hreflangLinks   : true
	}
};
```

See [Settings](../readme.md#settings) for what each one does.

## Upgrade

1. Read the [changelog](../CHANGELOG.md) for the new version.
2. Replace the module: `box update contentbox-studio`, or unpack the new zip over `modules_app/contentbox-studio`
   (from git: `git pull` and build `ui/` again).
3. Reinit the site.

There are no database migrations: Studio's data is part of ContentBox's own (see below). Block data carries the
version of its block type (`v`), so a new version of a block type can still read blocks saved with an older one
([block format](block-format.md)).

Pages store the HTML their blocks rendered when they were saved. After changing block templates (a Studio update with
new core block markup, or a theme update), re-render the stored HTML of a site:
`POST /cbstudio/api/blocks/rerender` with `{ "site": "<site slug>" }`, as an author with `THEME_ADMIN` (the access
token of ContentBox's API login, `POST /cbapi/v1/login`, as `x-auth-token`). Content whose HTML changes gets a new
version; content whose blocks were changed outside Studio is skipped and listed.

## Remove

1. `box uninstall contentbox-studio` (or delete `modules_app/contentbox-studio`).
2. Reinit the site.

Nothing breaks: content made with Studio is ordinary ContentBox content. The block data is stored as HTML comments in
the content's body next to the rendered HTML, so pages look the same and the classic editor shows the HTML. What
Studio leaves behind, all harmless and removable in the classic admin:

| What | Where |
|---|---|
| Permissions `STUDIO_ACCESS`, `STUDIO_SITE_TREE`, `STUDIO_HTML_BLOCKS`, `STUDIO_CONVERT` | Users → Permissions |
| Custom fields `cbstudio_language`, `cbstudio_translationGroup` (languages and translation groups) | on pages and blog entries |
| Site setting `cbstudio_copiedFrom` | on sites made by the conversion tool |
| Content templates saved with **Save as template** | Content → Content Templates |
