# ContentBox Studio

Block editor and site tree for [ContentBox](https://www.contentboxcms.org) 7, running next to the classic admin at `/cbstudio`.

> Status: early development, not usable yet.

## Goals

- **Block editor:** pages are built from sections (blocks) that the theme defines, edited as fields with a live preview instead of raw HTML.
- **Site tree:** drag and drop for order and parent page, status at a glance, translation groups.
- **No lock-in:** block data is stored as HTML comments inside the normal content body. Existing pages keep working, versions and the API keep working, and uninstalling leaves plain HTML.
- **Uses ContentBox's own users, roles and permissions** and the ContentBox REST API (JWT).

## Requirements

- ContentBox 7
- BoxLang, Lucee or Adobe ColdFusion as supported by ContentBox 7

## Installation

```bash
box install contentbox-studio
```

Then reinit the site and open `/cbstudio`. Studio uses the classic admin login.

## Permissions

Studio adds these permissions when it loads (only if they are missing, so your changes in the admin are kept):

| Permission | Allows | Granted on creation to |
|---|---|---|
| `STUDIO_ACCESS` | Opening Studio and using its API | Administrator, Editor |
| `STUDIO_SITE_TREE` | Moving and reordering pages in the site tree | Administrator, Editor |
| `STUDIO_HTML_BLOCKS` | Adding and editing raw HTML blocks | Administrator |

## How it works

- `/cbstudio` needs a classic admin session with `STUDIO_ACCESS`; without a session you go through the admin login
  (including two-factor authentication) and come back.
- The page passes JWT tokens for the logged-in author to the React app, which uses them for the ContentBox REST API
  (`/cbapi/v1`) and the Studio API (`/cbstudio/api`). Expired access tokens are refreshed automatically.

## Blocks

- A page is a sequence of blocks stored **inside the normal content body**: each block is an HTML comment with its
  data, followed by its rendered HTML ([block format](docs/block-format.md)). Versions, search, the REST API and
  exports keep working; on the public site Studio removes the comments.
- Block types come from Studio (HTML, text, heading, image, gallery, button, quote, content store item), from the
  site's theme and from other modules ([theme blocks](docs/theme-blocks.md)).
- The server renders blocks when they are saved. Rich text is stored as a structured document and rendered by the
  server, so it cannot carry arbitrary HTML; raw HTML needs the `HTML` block and the `STUDIO_HTML_BLOCKS` permission.
- In the classic admin, block content shows a notice with a link to Studio and its body is read-only; saving there
  keeps the blocks and changes only the other settings.

## Site tree

- `/cbstudio` shows the pages of a site as a tree with status (published, draft, scheduled, expired), a badge for
  block content and the language. Search keeps matches in place.
- Drag and drop (or the arrow buttons) moves and reorders pages; it needs `STUDIO_SITE_TREE` and `PAGES_ADMIN` or
  `PAGES_EDITOR`. Moving changes the address of the page and its subpages; ContentBox redirects the old ones.
- **Translation groups:** pages and blog entries in different languages, also on different sites, can be linked.
  Each page gets a language code; the public pages get `hreflang` links, and themes can build a language switcher
  from `getInstance( "Translations@contentbox-studio" ).forContent( prc.page ).members`. Stored as the custom fields
  `cbstudio_language` and `cbstudio_translationGroup`.

## Development

The module is developed inside a ContentBox 7 site, linked as `modules_app/contentbox-studio`.

```bash
cd ui
npm ci
npm run build        # builds the app into dist/, which the module serves
npm test             # Vitest
npm run typecheck
```

- **Hot reload:** set `CBSTUDIO_DEV_SERVER=http://localhost:5173` in the site's `.env`, restart the server, run
  `npm run dev` in `ui/` and open `/cbstudio`.
- **CFML tests (TestBox):** open `/modules_app/contentbox-studio/tests/runner.cfm` on the site. They reuse ContentBox's
  test application (`tests/Application.cfc` of a ContentBox source checkout) and the ORM dialect from `ORM_DIALECT`.
- **CI** (`.github/workflows/ci.yml`): UI checks, then the TestBox suite in a ContentBox `development` checkout with its
  MySQL fixture on BoxLang 1 and Adobe ColdFusion 2023/2025.

## License

Apache License 2.0, see [LICENSE](LICENSE).
