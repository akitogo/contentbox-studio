/**
 * Escaping and URL checks for block output.
 *
 * Text is escaped for HTML and also defused for ContentBox's content renderers, which run over the rendered page:
 * `{` and `[` become entities, so text like {{{Widget}}} or page:[slug] typed by an editor stays text.
 * Links may use ContentBox's link syntax on purpose (page:[slug], entry:[slug], root:[path]); those are kept as is,
 * so ContentBox resolves them when the page renders.
 */
component singleton {
	variables.SCHEMES = [ "http", "https", "mailto", "tel" ];
	variables.IMAGE_SCHEMES = [ "http", "https" ];

	function init() {
		var pattern = createObject( "java", "java.util.regex.Pattern" );
		variables.contentBoxLink = pattern.compile(
			"^(page|pagessl|entry|entryssl|root):\[[A-Za-z0-9_./-]*\]$"
		);
		variables.schemePrefix = pattern.compile( "^([A-Za-z][A-Za-z0-9+.-]*):" );
		variables.controlChars = pattern.compile( "[\x00-\x1f\x7f]" );
		return this;
	}

	/**
	 * Escape text for HTML content and double-quoted attributes
	 */
	string function esc( any text = "" ) {
		if ( !isSimpleValue( arguments.text ) ) {
			return "";
		}
		var html = replace(
			arguments.text,
			"&",
			"&amp;",
			"all"
		);
		html = replace(
			html,
			"<",
			"&lt;",
			"all"
		);
		html = replace(
			html,
			">",
			"&gt;",
			"all"
		);
		html = replace(
			html,
			"""",
			"&quot;",
			"all"
		);
		html = replace(
			html,
			"'",
			"&##39;",
			"all"
		);
		html = replace(
			html,
			"{",
			"&##123;",
			"all"
		);
		return replace(
			html,
			"[",
			"&##91;",
			"all"
		);
	}

	/**
	 * Escaped text with line breaks as <br>
	 */
	string function nl2br( any text = "" ) {
		return reReplace(
			esc( arguments.text ),
			"\r\n|\r|\n",
			"<br>",
			"all"
		);
	}

	boolean function isContentBoxLink( required string href ) {
		return variables
			.contentBoxLink
			.matcher( arguments.href )
			.matches();
	}

	/**
	 * A link target that is safe to output, or "" if it is not.
	 * Allowed: http, https, mailto, tel, relative URLs, #anchors and ContentBox link syntax. Spaces become %20; other
	 * whitespace and control characters are refused (browsers drop them, which can turn "java&#9;script:" into a scheme).
	 */
	string function safeUrl( any href = "", array schemes = variables.SCHEMES ) {
		if ( !isSimpleValue( arguments.href ) ) {
			return "";
		}
		// Not "url": that is CFML's URL scope
		var candidate = replace(
			trim( arguments.href ),
			" ",
			"%20",
			"all"
		);
		if (
			!len( candidate ) ||
				variables
					.controlChars
					.matcher( candidate )
					.find()
		) {
			return "";
		}
		if ( isContentBoxLink( candidate ) ) {
			return candidate;
		}
		var scheme = variables.schemePrefix.matcher( candidate );
		if ( scheme.find() && !arguments.schemes.findNoCase( scheme.group( javacast( "int", 1 ) ) ) ) {
			return "";
		}
		return candidate;
	}

	/**
	 * An image source that is safe to output (http, https or relative), or ""
	 */
	string function safeImageUrl( any src = "" ) {
		var safe = safeUrl( arguments.src, variables.IMAGE_SCHEMES );
		return isContentBoxLink( safe ) ? "" : safe;
	}

	/**
	 * A safe URL ready for an href attribute: ContentBox link syntax raw (so ContentBox resolves it), anything else
	 * escaped. "" if the URL is not safe.
	 */
	string function href( any link = "" ) {
		var safe = safeUrl( arguments.link );
		return isContentBoxLink( safe ) ? safe : esc( safe );
	}

}