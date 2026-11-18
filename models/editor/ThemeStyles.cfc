/**
 * The stylesheets of a site's theme, so the editor canvas shows blocks with the theme's look.
 *
 * - all <link rel="stylesheet"> of the site's home page (fetched by the server, so it works for every site domain)
 * - plus blocks/editor.css of the active theme, if it has one: CSS a theme can add for the editor only
 *
 * Cached per site for 10 minutes. If the home page cannot be fetched, only editor.css is used.
 */
component singleton {
	property name="themeService" inject="provider:themeService@contentbox";

	property name="log" inject="logbox:logger:{this}";
	variables.CACHE_MINUTES = 10;

	function init() {
		variables.cache = {};
		return this;
	}

	/**
	 * @return Absolute URLs of stylesheets
	 */
	array function stylesheets( required site ) {
		var key = arguments.site.getSiteID();
		var cached = variables.cache[ key ] ?: {};
		if (
			!cached.isEmpty() &&
				dateDiff(
						"n",
						cached.time,
						now()
					) <
					variables.CACHE_MINUTES
		) {
			return cached.urls;
		}

		var root = reReplace(
			arguments.site.getSiteRoot(),
			"/+$",
			""
		);
		var urls = fromPage( root & "/", root );

		var theme = variables.themeService.getThemeRecord( arguments.site.getActiveTheme() );
		if ( fileExists( theme.path & "/" & theme.name & "/blocks/editor.css" ) ) {
			urls.append( root & theme.includePath & "/blocks/editor.css" );
		}

		variables.cache[ key ] = { "time": now(), "urls": urls };
		return urls;
	}

	void function clearCache() {
		variables.cache = {};
	}

	/**
	 * Stylesheet links of a page, resolved against the site root
	 */
	array function fromPage( required string pageUrl, required string root ) {
		var html = fetch( arguments.pageUrl );
		var urls = [];
		var tags = reMatchNoCase( "<link\b[^>]*>", html );
		for ( var tag in tags ) {
			if ( !reFindNoCase( "\brel\s*=\s*[""']?stylesheet", tag ) ) {
				continue;
			}
			var href = reReplaceNoCase(
				tag,
				".*\bhref\s*=\s*[""']?([^""' >]+).*",
				"\1"
			);
			if ( href == tag || !len( href ) ) {
				continue;
			}
			href = replace(
				href,
				"&amp;",
				"&",
				"all"
			);
			if ( reFindNoCase( "^https?://", href ) ) {
				urls.append( href );
			} else if ( left( href, 2 ) == "//" ) {
				urls.append( listFirst( arguments.root, ":" ) & ":" & href );
			} else if ( left( href, 1 ) == "/" ) {
				urls.append(
					reReplace(
						arguments.root,
						"^(https?://[^/]+).*",
						"\1"
					) & href
				);
			} else {
				urls.append( arguments.root & "/" & href );
			}
		}
		return urls;
	}

	/**
	 * GET a page with Java's HTTP client (same on every engine); "" on any problem
	 */
	private string function fetch( required string pageUrl ) {
		try {
			// Not "client" / "request": those are CFML scopes
			var httpClient = createObject( "java", "java.net.http.HttpClient" ).newHttpClient();
			var httpRequest = createObject( "java", "java.net.http.HttpRequest" )
				.newBuilder( createObject( "java", "java.net.URI" ).create( arguments.pageUrl ) )
				.timeout( createObject( "java", "java.time.Duration" ).ofSeconds( 8 ) )
				.header( "Cookie", "cbstudio=styles" )
				// A cookie, so ContentBox's rate limiter (bots only) does not count this request as a bot

				.build();
			var response = httpClient.send(
				httpRequest,
				createObject( "java", "java.net.http.HttpResponse$BodyHandlers" ).ofString()
			);
			return response.statusCode() == 200 ? response.body() : "";
		} catch (any e) {
			variables.log.warn(
				"ContentBox Studio could not read the theme styles from #arguments.pageUrl#: #e.message#"
			);
			return "";
		}
	}

}