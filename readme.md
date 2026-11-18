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

Then open `/cbstudio`.

## License

Apache License 2.0, see [LICENSE](LICENSE).
