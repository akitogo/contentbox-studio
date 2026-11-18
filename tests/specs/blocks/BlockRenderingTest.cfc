/**
 * Block registry (core and theme block types) and the renderer with the core blocks
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"Block registry",
			() => {
				beforeEach(
					() => {
						registry = getInstance( "BlockRegistry@contentbox-studio" );
					}
				);

				it(
					"has the core block types on a site whose theme has none",
					() => {
						var types = registry.forSite( getDefaultSite() );
						for ( var name in [
							"html",
							"text",
							"heading",
							"image",
							"gallery",
							"button",
							"quote",
							"contentStore"
						] ) {
							expect( types ).toHaveKey( name );
							expect( types[ name ].source ).toBe( "core" );
						}
					}
				);

				it(
					"adds theme block types, lets them override core ones, skips broken ones and keeps the core html",
					() => {
						var types = registry.forTheme( fixtureTheme() );
						expect( types.hero.source ).toBe( "theme" );
						expect( types.hero.version ).toBe( 2 );
						expect( types.heading.source ).toBe( "theme" );
						expect( types.html.source ).toBe( "core" );
						expect( types ).notToHaveKey( "broken" );
						expect( types ).notToHaveKey( "norender" );
					}
				);

				it(
					"gives the editor definitions without template paths",
					() => {
						var list = registry.publicDefinitions( registry.forSite( getDefaultSite() ) );
						expect( list.len() ).toBeGTE( 8 );
						expect( list[ 1 ] ).notToHaveKey( "renderTemplate" );
						expect( list[ 1 ] ).toHaveKey( "fields" );
					}
				);
			}
		);

		describe(
			"Block renderer",
			() => {
				beforeEach(
					() => {
						renderer = getInstance( "BlockRenderer@contentbox-studio" );
						format = getInstance( "BlockFormat@contentbox-studio" );
					}
				);

				it(
					"renders the core blocks",
					() => {
						var result = renderer.renderBlocks(
							getDefaultSite(),
							[
								{
									"type": "heading",
									"id"  : "h1",
									"data": { "text": "Rooms & {{{x}}}", "level": "3" }
								},
								{
									"type": "text",
									"id"  : "t1",
									"data": {
										"content": {
											"type"   : "doc",
											"content": [
												{
													"type"   : "paragraph",
													"content": [ { "type": "text", "text": "Sea view" } ]
												}
											]
										}
									}
								},
								{
									"type": "image",
									"id"  : "i1",
									"data": {
										"image"  : { "src": "/__media/a.jpg", "alt": "A ""room""" },
										"caption": "Room",
										"link"   : { "href": "page:[rooms]" }
									}
								},
								{
									"type": "gallery",
									"id"  : "g1",
									"data": {
										"images" : [ "/a.jpg", { "src": "/b.jpg", "alt": "B" } ],
										"columns": "2"
									}
								},
								{
									"type": "button",
									"id"  : "b1",
									"data": {
										"label": "Book",
										"link" : { "href": "https://example.com/book", "target": "_blank" }
									}
								},
								{
									"type": "quote",
									"id"  : "q1",
									"data": {
										"quote": "Line one#chr( 10 )#Line two",
										"cite" : "Guest"
									}
								},
								{
									"type": "contentStore",
									"id"  : "c1",
									"data": { "slug": "footer-cta" }
								},
								{
									"type": "html",
									"id"  : "x1",
									"data": { "html": "<p>raw</p>" }
								}
							]
						);

						expect( result.errors ).toBeEmpty();
						var html = result.blocks.map( ( block ) => block.html );
						expect( html[ 1 ] ).toBeWithCase(
							"<h3 class=""cbs-heading"">Rooms &amp; &##123;&##123;&##123;x}}}</h3>"
						);
						expect( html[ 2 ] ).toBeWithCase( "<div class=""cbs-text""><p>Sea view</p></div>" );
						expect( html[ 3 ] ).toBeWithCase(
							"<figure class=""cbs-image""><a href=""page:[rooms]""><img src=""/__media/a.jpg"" alt=""A &quot;room&quot;"" loading=""lazy""></a><figcaption>Room</figcaption></figure>"
						);
						expect( html[ 4 ] ).toBeWithCase(
							"<div class=""cbs-gallery cbs-gallery--2""><figure class=""cbs-gallery__item""><img src=""/a.jpg"" alt="""" loading=""lazy""></figure><figure class=""cbs-gallery__item""><img src=""/b.jpg"" alt=""B"" loading=""lazy""></figure></div>"
						);
						expect( html[ 5 ] ).toBeWithCase(
							"<p class=""cbs-button""><a class=""cbs-button__link cbs-button__link--primary"" href=""https://example.com/book"" target=""_blank"" rel=""noopener noreferrer"">Book</a></p>"
						);
						expect( html[ 6 ] ).toBeWithCase(
							"<blockquote class=""cbs-quote""><p>Line one<br>Line two</p><footer><cite>Guest</cite></footer></blockquote>"
						);
						expect( html[ 7 ] ).toBeWithCase( "{{{ContentStore slug=""footer-cta""}}}" );
						expect( html[ 8 ] ).toBeWithCase( "<p>raw</p>" );

						// The body parses back into the same blocks
						var parsed = format.parse( result.body );
						expect( parsed.map( ( block ) => block.id ) ).toBe(
							[
								"h1",
								"t1",
								"i1",
								"g1",
								"b1",
								"q1",
								"c1",
								"x1"
							]
						);
						expect( parsed.every( ( block ) => block.status == "ok" ) ).toBeTrue();
					}
				);

				it(
					"reports unknown types and field errors, and replaces missing or duplicate ids",
					() => {
						var result = renderer.renderBlocks(
							getDefaultSite(),
							[
								{ "type": "nope", "id": "n1", "data": {} },
								{
									"type": "heading",
									"id"  : "same",
									"data": { "text": "" }
								},
								{
									"type": "heading",
									"id"  : "same",
									"data": { "text": "B" }
								},
								{ "type": "heading", "data": { "text": "C" } }
							]
						);
						expect( result.blocks.len() ).toBe( 3 );
						expect( result.errors.map( ( error ) => error.message ) ).toInclude(
							"Unknown block type [nope]"
						);
						expect( result.errors.map( ( error ) => error.blockID ) ).toInclude( "same" );
						var ids = result.blocks.map( ( block ) => block.id );
						expect( ids[ 1 ] ).toBe( "same" );
						expect( ids[ 2 ] ).notToBe( "same" );
						expect( format.isValidId( ids[ 3 ] ) ).toBeTrue();
					}
				);

				it(
					"renders theme blocks with list fields",
					() => {
						var types = getInstance( "BlockRegistry@contentbox-studio" ).forTheme( fixtureTheme() );
						var result = renderer.renderBlocks(
							getDefaultSite(),
							[
								{
									"type": "hero",
									"id"  : "hero1",
									"data": {
										"title": "Welcome",
										"links": [ { "label": "Rooms", "link": { "href": "/rooms" } } ]
									}
								}
							],
							types
						);
						expect( result.errors ).toBeEmpty();
						expect( result.blocks[ 1 ].v ).toBe( 2 );
						expect( result.blocks[ 1 ].html ).toBeWithCase(
							"<section class=""hero""><h1>Welcome</h1><a href=""/rooms"">Rooms</a></section>"
						);
					}
				);

				describe(
					"re-rendering a stored body",
					() => {
						it(
							"renders Studio blocks again and keeps legacy parts",
							() => {
								var stored = renderer.renderBlocks(
									getDefaultSite(),
									[
										{
											"type": "heading",
											"id"  : "h1",
											"data": { "text": "Old" }
										}
									]
								).body;
								stored = replace(
									stored,
									"cbs-heading",
									"old-class"
								) & chr( 10 ) & chr( 10 ) & "<p>legacy</p>";
								// The hash no longer matches after the class change: that counts as an edit outside Studio
								expect( renderer.rerenderBody( getDefaultSite(), stored ).skipped ).toBe(
									"blocks changed outside Studio"
								);

								var clean = renderer.renderBlocks(
									getDefaultSite(),
									[
										{
											"type": "heading",
											"id"  : "h1",
											"data": { "text": "Old" }
										}
									]
								).body & chr( 10 ) & chr( 10 ) & "<p>legacy</p>";
								var result = renderer.rerenderBody( getDefaultSite(), clean );
								expect( result.skipped ).toBe( "" );
								expect( result.changed ).toBe( 0 );
								var blocks = format.parse( result.body );
								expect( blocks.map( ( block ) => block.type ) ).toBe( [ "heading", "html" ] );
								expect( blocks[ 2 ].html ).toBeWithCase( "<p>legacy</p>" );
							}
						);

						it(
							"does not touch bodies without Studio blocks",
							() => {
								var result = renderer.rerenderBody(
									getDefaultSite(),
									"<p>Written in the classic editor</p>"
								);
								expect( result.skipped ).toBe( "no blocks" );
								expect( result.body ).toBeWithCase( "<p>Written in the classic editor</p>" );
							}
						);
					}
				);
			}
		);

		describe(
			"Output and classic admin",
			() => {
				beforeEach(
					() => {
						setup();
						format = getInstance( "BlockFormat@contentbox-studio" );
						renderer = getInstance( "BlockRenderer@contentbox-studio" );
						body = renderer.renderBlocks(
							getDefaultSite(),
							[
								{
									"type": "heading",
									"id"  : "h1",
									"data": { "text": "Hi" }
								}
							]
						).body;
					}
				);

				it(
					"removes the block markers from rendered content",
					() => {
						var builder = createObject( "java", "java.lang.StringBuilder" ).init(
							body & chr( 10 ) & chr( 10 ) & "<p>after</p>"
						);
						getInterceptor( "BlockOutput@contentbox-studio" ).cb_onContentRendering(
							getRequestContext(),
							{ "builder": builder }
						);
						// Each marker goes together with the line break after it
						expect( builder.toString() ).toBeWithCase(
							"<h2 class=""cbs-heading"">Hi</h2>" & chr( 10 ) & chr( 10 ) & "<p>after</p>"
						);
					}
				);

				it(
					"keeps the block body when the classic editor saves",
					() => {
						var page = pageWithVersions( [ body, "<p>reformatted by CKEditor</p>" ] );
						getInterceptor( "ClassicAdmin@contentbox-studio" ).cbadmin_prePageSave(
							getRequestContext(),
							{ "content": page.content, "isNew": false }
						);
						expect( page.active.$count( "setContent" ) ).toBe( 1 );
						expect( page.active.$callLog().setContent[ 1 ][ 1 ] ).toBeWithCase( body );
					}
				);

				it(
					"lets the classic editor save content without blocks",
					() => {
						var page = pageWithVersions( [ "<p>old</p>", "<p>new</p>" ] );
						getInterceptor( "ClassicAdmin@contentbox-studio" ).cbadmin_prePageSave(
							getRequestContext(),
							{ "content": page.content, "isNew": false }
						);
						expect( page.active.$count( "setContent" ) ).toBe( 0 );
					}
				);

				it(
					"shows a notice with a Studio link in the classic editor for block content",
					() => {
						var content = createStub()
							.$( "isLoaded", true )
							.$( "getContent", body )
							.$( "getContentID", "abc123" );
						var event = getRequestContext();
						event.setPrivateValue( "oContent", content );
						var buffer = createObject( "java", "java.lang.StringBuilder" ).init();

						getInterceptor( "ClassicAdmin@contentbox-studio" ).cbadmin_contentEditorFooter(
							event,
							{},
							buffer
						);

						expect( buffer.toString() ).toInclude( "Open in Studio" );
						expect( buffer.toString() ).toInclude( "cbstudio/content/abc123" );
					}
				);
			}
		);
	}

	/********************************* HELPERS *********************************/

	private function getDefaultSite() {
		return getInstance( "siteService@contentbox" ).getDefaultSite();
	}

	private struct function fixtureTheme() {
		return {
			"name"       : "fixture",
			"path"       : expandPath( "/cbstudioTests/fixtures/themes" ),
			"includePath": "/cbstudioTests/fixtures/themes/fixture"
		};
	}

	private function getInterceptor( required string name ) {
		return getController().getInterceptorService().getInterceptor( arguments.name );
	}

	/**
	 * Content as the classic admin leaves it before saving: the posted body is the new active version, the previous
	 * versions are inactive. Stubs, so the test does not depend on how an engine treats unsaved ORM entities.
	 *
	 * @return { content, active } where active is the stub of the new version
	 */
	private struct function pageWithVersions( required array bodies ) {
		var versions = [];
		for ( var i = 1; i <= arguments.bodies.len(); i++ ) {
			versions.append(
				createStub()
					.$( "getIsActive", i == arguments.bodies.len() )
					.$( "getVersion", i )
					.$( "getContent", arguments.bodies[ i ] )
					.$( "setContent" )
			);
		}
		var content = createStub().$( "getContentVersions", versions ).$( "getSlug", "studio-test" );
		return {
			"content": content,
			"active" : versions[ versions.len() ]
		};
	}

}