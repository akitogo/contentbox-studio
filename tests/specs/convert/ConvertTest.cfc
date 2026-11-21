/**
 * Conversion tool (models/convert/): field readers, comparisons, profiles, converting bodies, applying, copying a
 * site and the API. Uses the fixture theme tests/fixtures/themes/convert (blocks that reproduce "old" markup) and the
 * profiles in tests/fixtures/convert.
 */
component extends="cbstudioTests.resources.StudioBaseTest" {
	variables.MARKER = "cbstudio-convert";

	function beforeAll() {
		super.beforeAll();
		getInstance( "Profiles@contentbox-studio" ).registerDirectory(
			expandPath( "/cbstudioTests/fixtures/convert" ),
			"cbstudioTests.fixtures.convert"
		);
	}

	function run( testResults, testBox ) {
		describe(
			"Conversion tool",
			() => {
				beforeEach(
					() => {
						setup();
						reader = getInstance( "FieldReader@contentbox-studio" );
						tree = getInstance( "HtmlTree@contentbox-studio" );
						profiles = getInstance( "Profiles@contentbox-studio" );
						converter = getInstance( "PageConverter@contentbox-studio" );
						types = getInstance( "BlockRegistry@contentbox-studio" ).forTheme( convertTheme() );
					}
				);

				afterEach(
					() => {
						deleteTestPages( variables.MARKER );
					}
				);

				it(
					"reads each field type from HTML, and refuses markup a field cannot hold",
					() => {
						var section = element(
							"<section class=""box box--dark wide"" data-n=""3""><h2> A   title </h2><p>One<br> two</p>" &
							"<div class=""rt""><h3>Head</h3>Loose <strong>bold <em>both</em></strong><ul><li>Item <a href=""/x"" target=""_blank"">link</a></li></ul></div>" &
							"<a class=""more"" href=""page:[about]"">More</a><img src=""/__media/a.png"" alt=""An image"" width=""640"">" &
							"<img src=""/__media/b.png"" alt=""""><span class=""n"">42</span></section>"
						);
						expect( reader.readField( section, fieldDef( "t", "text" ), "h2" ) ).toBe( "A title" );
						expect( reader.readField( section, fieldDef( "t", "textarea" ), "p" ) ).toBe( "One" & chr( 10 ) & "two" );
						expect( reader.readField( section, fieldDef( "t", "text" ), "img @alt" ) ).toBe( "An image" );
						expect( reader.readField( section, fieldDef( "t", "text" ), "@data-n" ) ).toBe( "3" );
						expect( reader.readField( section, fieldDef( "n", "number" ), "span.n" ) ).toBe( 42 );
						expect( reader.readField( section, fieldDef( "t", "text" ), "h6" ) ).toBe( "" );
						expect( reader.readField( section, fieldDef( "t", "text" ), { "value": "fixed" } ) ).toBe( "fixed" );

						var tone = fieldDef( "tone", "select", { "options": [ "light", { "value": "dark", "label": "Dark" } ] } );
						expect( reader.readField( section, tone, { "classes": { "box--dark": "dark" } } ) ).toBe( "dark" );
						expect( reader.readField( section, tone, { "classes": { "nothing": "dark" } } ) ).toBe( "" );
						expect( () => reader.readField( section, tone, { "classes": { "box--dark": "black" } } ) ).toThrow( "Convert.Unconvertible" );
						expect( reader.readField( section, fieldDef( "w", "boolean" ), { "classes": { "wide": true } } ) ).toBeTrue();
						expect( reader.readField( section, fieldDef( "w", "boolean" ), "h6" ) ).toBeFalse();

						expect( reader.readField( section, fieldDef( "l", "link" ), "a.more" ) ).toBe( { "href": "page:[about]", "target": "" } );
						expect( reader.readField( section, fieldDef( "i", "image" ), "img" ) ).toBe( { "src": "/__media/a.png", "alt": "An image", "width": 640 } );
						expect( reader.readField( section, fieldDef( "i", "images" ), "img" ).len() ).toBe( 2 );
						expect( () => reader.readField( section, fieldDef( "l", "link" ), "h2" ) ).toThrow( "Convert.Unconvertible" );

						var doc = reader.readField( section, fieldDef( "r", "richtext" ), "div.rt" );
						expect( doc.content.map( ( node ) => node.type ) ).toBe( [ "heading", "paragraph", "bulletList" ] );
						expect( doc.content[ 1 ].attrs.level ).toBe( 3 );
						expect( doc.content[ 2 ].content[ 1 ] ).toBe( { "type": "text", "text": "Loose " } );
						expect( doc.content[ 2 ].content[ 3 ].marks.map( ( mark ) => mark.type ) ).toBe( [ "bold", "italic" ] );
						var link = doc.content[ 3 ].content[ 1 ].content[ 1 ].content[ 2 ];
						expect( link.marks[ 1 ] ).toBe( { "type": "link", "attrs": { "href": "/x", "target": "_blank" } } );

						// Markup a field cannot hold: the section stays HTML instead of losing it
						expect( () => reader.readField( section, fieldDef( "t", "text" ), "div.rt" ) ).toThrow( "Convert.Unconvertible" );
						expect( () => reader.readField( section, fieldDef( "r", "richtext" ), "&" ) ).toThrow( "Convert.Unconvertible" );
						expect( () => reader.readField( section, fieldDef( "t", "text" ), "h2[" ) ).toThrow( "Convert.InvalidProfile" );

						var list = reader.readField(
							element( "<ul><li><b>A</b><i>1</i></li><li><b>B</b></li></ul>" ),
							fieldDef( "items", "list", { "fields": [ fieldDef( "name", "text" ), fieldDef( "note", "text" ) ] } ),
							{ "each": "li", "fields": { "name": "b", "note": "i" } }
						);
						expect( list ).toBe( [ { "name": "A", "note": "1" }, { "name": "B", "note": "" } ] );
					}
				);

				it(
					"compares markup canonically and content by what is missing",
					() => {
						expect( tree.canonical( "<p class=""b a"" id=""x"">Hi &amp; <br>  there</p>" ) ).toBe(
							tree.canonical( "<p id='x' class='a b'>Hi &##38;<br>there</p><!-- note -->" )
						);
						expect( tree.canonical( "<p class=""a"">Hi</p>" ) ).notToBe( tree.canonical( "<p class=""b"">Hi</p>" ) );

						var old = "<div><h4>Title</h4><p>Some&nbsp;text</p><a href=""/go"">Go</a><img src=""/i.png"" alt=""Alt""></div>";
						expect(
							tree.missingContent( old, "<section><h2>Title</h2><p>Some text</p><a class=""btn"" href=""/go"">Go</a><span>Extra</span><img src=""/i.png"" alt=""Alt""></section>" )
						).toBeEmpty();
						expect( tree.missingContent( old, "<section><h2>Title</h2><a href=""/other"">Go</a></section>" ) ).toBe(
							[ "Text: Some text", "Text: Alt", "Link: /go", "Image: /i.png" ]
						);
					}
				);

				it(
					"lists profiles and reports what is wrong with them",
					() => {
						var listed = profiles.list().filter( ( profile ) => left( profile.label, 8 ) == "Fixture:" );
						expect( listed.map( ( profile ) => profile.name ) ).toBe( [ "broken", "newlook", "same", "unknown" ] );

						var broken = profiles.get( "broken" );
						expect( broken.problems ).toHaveLength( 5 );
						expect( broken.problems[ 1 ] ).toInclude( "theme" );
						expect( broken.problems[ 2 ] ).toInclude( "compare" );
						expect( broken.problems[ 5 ] ).toInclude( "readers/missing.cfc" );

						var unknown = converter.checkRules( profiles.get( "unknown" ), types );
						expect( unknown ).toHaveLength( 4 );
						expect( unknown[ 1 ] ).toInclude( "no block 'nope'" );
						expect( unknown[ 2 ] ).toInclude( "invalid match selector" );
						expect( unknown[ 3 ] ).toInclude( "no field 'subtitle'" );
						expect( unknown[ 4 ] ).toInclude( "no field 'heading'" );

						expect( () => profiles.get( "../same" ) ).toThrow( "Convert.ProfileNotFound" );
						expect( () => profiles.get( "nothing" ) ).toThrow( "Convert.ProfileNotFound" );

						var prepared = converter.prepare( coreSite(), "same", types );
						expect( prepared.problems ).toHaveLength( 1 );
						expect( prepared.problems[ 1 ] ).toInclude( "theme 'convert'" );
					}
				);

				it(
					"converts sections that render the same markup and keeps the rest as HTML",
					() => {
						var banner = "<section class=""banner banner--dark banner--wide""><h2>Hello &amp; welcome</h2><p>Line one<br>Line two</p>" &
						"<img src=""/__media/banner.png"" alt=""Beach""><a class=""btn"" href=""page:[contact]"">Write us</a></section>";
						var steps = "<ol class=""steps""><li><h3>First</h3><div class=""body""><p>Do <strong>this</strong></p></div></li>" &
						"<li><h3>Second</h3><div class=""body""><p>Then that</p></div></li></ol>";
						var body = banner & chr( 10 ) & "<div class=""legacy"">Old</div><p>Loose text</p>" & chr( 10 ) &
						"{{{ContentStore slug=""footer""}}}" & steps;
						var item = converter.convert( contentWith( body ), profiles.get( "same" ), types );
						expect( item.sections.map( ( section ) => section.type ) ).toBe( [ "banner", "html", "contentStore", "steps" ] );
						expect( item.ready ).toBeTrue( item.reason );
						expect( item.sections[ 1 ].data.title ).toBe( "Hello & welcome" );
						expect( item.sections[ 1 ].data.tone ).toBe( "dark" );
						expect( item.sections[ 1 ].data.wide ).toBeTrue();
						// Neighbouring HTML parts are one block
						expect( item.sections[ 2 ].data.html ).toInclude( "Old" );
						expect( item.sections[ 2 ].data.html ).toInclude( "Loose text" );
						expect( item.sections[ 3 ].data.slug ).toBe( "footer" );
						expect( item.sections[ 4 ].data.items[ 1 ].title ).toBe( "First" );

						// An attribute the template does not output: the section differs, nothing is ready
						var different = converter.convert(
							contentWith( replace( banner, "<h2>", "<h2 id=""top"">" ) ),
							profiles.get( "same" ),
							types
						);
						expect( different.ready ).toBeFalse();
						expect( different.reason ).toBe( "1 section differs" );
						expect( different.sections[ 1 ].canonical.source ).toInclude( "id=""top""" );

						// Markup a field cannot hold: that section stays HTML, with the reason
						var kept = converter.convert(
							contentWith( replace( banner, "Hello &amp; welcome", "Hello <em>you</em>" ) & steps ),
							profiles.get( "same" ),
							types
						);
						expect( kept.sections.map( ( section ) => section.type ) ).toBe( [ "html", "steps" ] );
						expect( kept.sections[ 1 ].note ).toInclude( "banner: markup in a one-line text: <em>" );
						expect( kept.ready ).toBeTrue();

						expect( converter.convert( contentWith( "<p>Only text</p>" ), profiles.get( "same" ), types ).reason ).toBe(
							"no section recognized"
						);
						var withBlocks = getInstance( "BlockRenderer@contentbox-studio" ).renderBlocks(
							coreSite(),
							[ { "type": "heading", "data": { "text": "Blocks" } } ]
						).body;
						expect( converter.convert( contentWith( withBlocks ), profiles.get( "same" ), types ).reason ).toBe(
							"already has blocks"
						);
					}
				);

				it(
					"converts into a new look when no text, link or image is lost",
					() => {
						var promo = "<div class=""promo""><span class=""promo-title"">Summer</span><p class=""promo-text"">Sun<br>and sea</p>" &
						"<a href=""/book"">Book now</a></div>";
						var teaser = "<div class=""teaser""><h4>Teaser</h4><p class=""lead"">Short</p><img src=""/__media/t.png"" alt=""T""></div>";
						var item = converter.convert( contentWith( promo & teaser ), profiles.get( "newlook" ), types );
						expect( item.sections.map( ( section ) => section.type ) ).toBe( [ "banner", "banner" ] );
						expect( item.ready ).toBeTrue( item.reason );
						expect( item.sections[ 1 ].data.text ).toBe( "Sun" & chr( 10 ) & "and sea" );
						expect( item.sections[ 2 ].data.tone ).toBe( "dark" );

						// Text the rule does not read is lost: not ready, and the report says what
						var lossy = converter.convert(
							contentWith( replace( teaser, "</div>", "<small>Fine print</small></div>" ) ),
							profiles.get( "newlook" ),
							types
						);
						expect( lossy.ready ).toBeFalse();
						expect( lossy.sections[ 1 ].missing ).toBe( [ "Text: Fine print" ] );
					}
				);

				it(
					"applies only ready content, as a new version, and a new look only on a copy",
					() => {
						var directory = writeProfile(
							{
								"label"  : "Quotes",
								"theme"  : siteService().getDefaultSite().getActiveTheme(),
								"compare": "markup",
								"rules"  : [
									{
										"block" : "quote",
										"match" : "blockquote.cbs-quote",
										"fields": { "quote": "p", "cite": "cite" }
									}
								]
							}
						);
						try {
							var name = listLast( directory, "/\" );
							var site = siteService().getDefaultSite();
							var ready = createTestPage(
								slug = testSlug( variables.MARKER ),
								body = "<blockquote class=""cbs-quote""><p>To be<br>or not</p><footer><cite>Someone</cite></footer></blockquote>"
							);
							var notReady = createTestPage( slug = testSlug( variables.MARKER ), body = "<p>Nothing to convert</p>" );
							var versions = ready.getContentVersions().len();

							var result = converter.apply(
								site       = site,
								profile    = name,
								contentIDs = [ ready.getContentID(), notReady.getContentID(), "nothing" ],
								author     = getAdministrator()
							);
							expect( result.saved.map( ( saved ) => saved.contentID ) ).toBe( [ ready.getContentID() ] );
							expect( result.skipped.map( ( skipped ) => skipped.reason ) ).toBe( [ "no section recognized", "not found in this site" ] );

							ormClearSession();
							var converted = getInstance( "pageService@contentbox" ).get( ready.getContentID() );
							expect( converted.getContentVersions().len() ).toBe( versions + 1 );
							var blocks = getInstance( "BlockFormat@contentbox-studio" ).parse( converted.getContent() );
							expect( blocks[ 1 ].type ).toBe( "quote" );
							expect( blocks[ 1 ].data.cite ).toBe( "Someone" );

							// The report only covers this site's content; with a content ID, it has the HTML
							var report = converter.report( site, name, ready.getContentID() );
							expect( report.items ).toHaveLength( 1 );
							expect( report.items[ 1 ].reason ).toBe( "already has blocks" );

							// A new look is only applied to a copy
							writeProfile(
								{
									"theme"  : site.getActiveTheme(),
									"compare": "content",
									"rules"  : [ { "block": "quote", "match": "blockquote", "fields": { "quote": "p" } } ]
								},
								directory
							);
							expect( converter.report( site, name ).canApply ).toBeFalse();
							expect( () => converter.apply( site, name, [ notReady.getContentID() ], getAdministrator() ) ).toThrow(
								"Convert.Forbidden"
							);
						} finally {
							directoryDelete( directory, true );
						}
					}
				);

				it(
					"copies a site with its own translation groups, leaving the original as it is",
					() => {
						var copier = getInstance( "SiteCopy@contentbox-studio" );
						var translations = getInstance( "Translations@contentbox-studio" );
						var site = siteService().getDefaultSite();
						var german = createTestPage( slug = testSlug( variables.MARKER ) );
						var english = createTestPage( slug = testSlug( variables.MARKER ) );
						translations.setLanguage( german, "de" );
						translations.setLanguage( english, "en" );
						translations.link( german, english );
						var group = translations.forContent( german ).group;

						for (
							var invalid in [
								{ "slug": "Bad Slug", "domain": "copy.localhost", "theme": site.getActiveTheme() },
								{ "slug": site.getSlug(), "domain": "copy.localhost", "theme": site.getActiveTheme() },
								{ "slug": "cbstudio-copy", "domain": "http://copy.localhost/", "theme": site.getActiveTheme() },
								{ "slug": "cbstudio-copy", "domain": site.getDomain(), "theme": site.getActiveTheme() },
								{ "slug": "cbstudio-copy", "domain": "copy.localhost", "theme": "no-such-theme" }
							]
						) {
							expect(
								() => copier.copy( site, "Copy", invalid.slug, invalid.domain, invalid.theme )
							).toThrow( "SiteCopy.Invalid" );
						}

						var slug = "cbstudio-copy-" & lCase( left( replace( createUUID(), "-", "", "all" ), 8 ) );
						var copy = {};
						try {
							copy = copier.copy( site, "ZZ Studio copy test", slug, "#slug#.localhost", site.getActiveTheme() );
							ormClearSession();
							var copied = siteService().get( copy.siteID );
							var source = siteService().get( site.getSiteID() );
							expect( copied.getNumberOfPages() ).toBe( source.getNumberOfPages() );
							expect( copied.getNumberOfContentStore() ).toBe( source.getNumberOfContentStore() );
							expect( copied.getNumberOfEntries() ).toBe( source.getNumberOfEntries() );
							expect( copied.getDomainRegex() ).toBe( "^https?://#slug#\.localhost(:[0-9]+)?(/|\?|$)" );
							expect( copier.isCopy( copied ) ).toBeTrue();
							expect( copier.copiedFrom( copied ) ).toBe( site.getSiteID() );
							expect( copier.isCopy( site ) ).toBeFalse();
							// The copy's pattern matches its whole host only; whether it wins depends on the other sites' patterns
							expect( reFindNoCase( copied.getDomainRegex(), "http://#slug#.localhost:8589/page" ) ).toBeGT( 0 );
							expect( reFindNoCase( copied.getDomainRegex(), "http://other.test/?next=#slug#.localhost" ) ).toBe( 0 );
							expect( copy.reachable ).toBe( copier.siteForUrl( "http://#slug#.localhost/" ) == copy.siteID );
							expect( copy.warnings.len() ).toBe( copy.reachable ? 0 : 1 );

							// The copy's group has a new id and the same members; the original's is unchanged
							var copiedGerman = getInstance( "pageService@contentbox" ).findWhere( { "slug": german.getSlug(), "site": copied } );
							var copiedGroup = translations.forContent( copiedGerman );
							expect( copiedGroup.group ).notToBe( group );
							expect( copiedGroup.members ).toHaveLength( 2 );
							expect( copiedGroup.members.every( ( member ) => member.siteID == copy.siteID ) ).toBeTrue();
							var original = translations.forContent( getInstance( "pageService@contentbox" ).get( german.getContentID() ) );
							expect( original.group ).toBe( group );
							expect( original.members.map( ( member ) => member.siteID ) ).toBe( [ site.getSiteID(), site.getSiteID() ] );
						} finally {
							if ( copy.keyExists( "siteID" ) ) {
								ormClearSession();
								siteService().delete( siteService().get( copy.siteID ) );
								var media = getInstance( "mediaService@contentbox" ).getCoreMediaRoot( absolute = true ) & "/sites/" & slug;
								if ( directoryExists( media ) ) {
									directoryDelete( media, true );
								}
							}
							ormClearSession();
						}
					}
				);

				it(
					"has an API for administrators",
					() => {
						var token = tokenFor( getAdministrator() );
						var response = get( route = "/cbstudio/api/convert", params = { "x-auth-token": token } ).getResponse();
						expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
						expect( response.getData().profiles.map( ( profile ) => profile.name ) ).toInclude( "same" );
						expect( response.getData().themes ).notToBeEmpty();

						setup();
						response = get(
							route  = "/cbstudio/api/sites/default/convert",
							params = { "x-auth-token": token, "profile": "nothing" }
						).getResponse();
						expect( response.getStatusCode() ).toBe( 404 );

						setup();
						response = post(
							route  = "/cbstudio/api/sites/default/copy",
							params = { "x-auth-token": token, "name": "Copy", "slug": "Bad Slug", "domain": "x.localhost", "theme": "default" }
						).getResponse();
						expect( response.getStatusCode() ).toBe( 400 );

						withTemporaryAuthor(
							[ "STUDIO_ACCESS" ],
							( author ) => {
								setup();
								var forbidden = get(
									route  = "/cbstudio/api/convert",
									params = { "x-auth-token": tokenFor( author ) }
								).getResponse();
								expect( forbidden.getStatusCode() ).toBe( 403 );
							}
						);
					}
				);
			}
		);
	}

	/********************************* HELPERS *********************************/

	private struct function fieldDef( required string name, required string type, struct extra = {} ) {
		var result = { "name": arguments.name, "type": arguments.type };
		result.append( arguments.extra );
		return result;
	}

	private function element( required string html ) {
		return tree.children( tree.parse( arguments.html ) )[ 1 ];
	}

	private function contentWith( required string body ) {
		return createStub()
			.$( "getContent", arguments.body )
			.$( "getContentID", "stub" )
			.$( "getSlug", "stub" )
			.$( "getTitle", "Stub" )
			.$( "getContentType", "Page" )
			.$( "getSite", coreSite() );
	}

	private function coreSite() {
		return createStub().$( "getActiveTheme", "default" ).$( "getSiteID", siteService().getDefaultSite().getSiteID() );
	}

	private function siteService() {
		return getInstance( "siteService@contentbox" );
	}

	private struct function convertTheme() {
		return {
			"name"       : "convert",
			"path"       : expandPath( "/cbstudioTests/fixtures/themes" ),
			"includePath": "/cbstudioTests/fixtures/themes/convert"
		};
	}

	/**
	 * A profile in a temporary profile folder (a profile for the dev site's theme, which differs between machines)
	 *
	 * @return The profile's folder
	 */
	private string function writeProfile( required struct profile, string directory = "" ) {
		var target = arguments.directory;
		if ( !len( target ) ) {
			var root = getTempDirectory() & "cbstudio-profiles";
			if ( !directoryExists( root ) ) {
				directoryCreate( root );
			}
			getInstance( "Profiles@contentbox-studio" ).registerDirectory( root, "" );
			target = root & "/t" & lCase( left( replace( createUUID(), "-", "", "all" ), 10 ) );
			directoryCreate( target );
		}
		fileWrite( target & "/profile.json", serializeJSON( arguments.profile ) );
		return target;
	}

}
