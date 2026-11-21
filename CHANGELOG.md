# Changelog

All notable changes to ContentBox Studio. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [Semantic Versioning](https://semver.org/). Upgrading: see [docs/installation.md](docs/installation.md#upgrade).

## [Unreleased]

### Fixed

- After activating another theme or saving theme settings (e.g. another design preset), the editor canvas showed
  the previous stylesheets for up to 10 minutes. They are now cached per theme and cleared on both events, together
  with ContentBox's cached pages they are read from.

## [0.1.1] - 2026-11-21

### Fixed

- Images and links of the readme also work on ForgeBox (absolute addresses).

## [0.1.0] - 2026-11-21

First release.

### Added

- **Block editor** (Puck, TipTap) for pages, blog entries and content store items: sections from the theme and
  Studio's core blocks (text, heading, image, gallery, quote, button, content store item, HTML), fields with media
  library, page picker and rich text, text edited directly on the page, undo/redo, phone/tablet/laptop/full-width
  views, preview with the site's layout. The canvas uses the theme's stylesheets, so blocks look as on the site.
- **Versions** as ContentBox versions with change notes; loading an older version; saves based on an outdated version
  are refused.
- **Site tree** next to the editor: status, menu and language at a glance, search, drag and drop to move and reorder
  (old addresses redirect), new pages from content templates, resizable and collapsible.
- **Blog** in the same editor: entry list with search and filters, new entries, entry settings (publish and unpublish
  dates, categories, excerpt, featured image, comments), the entry's header on the canvas with its title edited in
  place.
- **Translation groups** of pages and entries within a site, with `hreflang` links on public pages.
- **Search engine fields** (title, description, keywords) with a preview of the search result.
- **Publish/unpublish** with ContentBox's permissions (editors save, publishers publish), a menu switch for pages,
  **Save as template** (block presets for new content).
- **Theme blocks:** themes add block types in `blocks/` (`block.json` + `render.cfm`), optional `blocks/editor.css`
  and a header template for blog entries; see [docs/theme-blocks.md](docs/theme-blocks.md).
- **Conversion tool** (`/cbstudio/convert`): existing HTML into blocks with conversion profiles, dry run with a check
  per section (same markup, or nothing lost for a new look), a copy of a site with another theme to convert without
  touching the original, deleting such copies, and a built-in profile that turns plain text into Studio's text,
  heading and image blocks; see [docs/conversion.md](docs/conversion.md).
- Classic admin integration: **Content → Studio** in the admin menu, a notice in the classic editor for content with
  blocks, and the block data kept when such content is saved there.
- Permissions `STUDIO_ACCESS`, `STUDIO_SITE_TREE`, `STUDIO_HTML_BLOCKS`, `STUDIO_CONVERT`, created on first start.
- Studio announces ContentBox's save events, so caches, menus, sitemap and notifications behave as with the classic
  admin.
- Tested on BoxLang 1 and Adobe ColdFusion 2023 and 2025.

[0.1.1]: https://github.com/akitogo/contentbox-studio/releases/tag/v0.1.1
[0.1.0]: https://github.com/akitogo/contentbox-studio/releases/tag/v0.1.0
