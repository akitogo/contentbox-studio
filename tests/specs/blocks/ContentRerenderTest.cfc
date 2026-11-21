/**
 * Re-rendering all block content of a site (models/blocks/ContentRerender.cfc, POST /cbstudio/api/blocks/rerender)
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"Re-rendering a site's block content",
			() => {
				beforeEach(
					() => {
						setup();
						format = getInstance( "BlockFormat@contentbox-studio" );
						rerender = getInstance( "ContentRerender@contentbox-studio" );
						pageService = getInstance( "pageService@contentbox" );
						site = getInstance( "siteService@contentbox" ).getDefaultSite();
					}
				);

				it(
					"lets ContentBox clear its cached rendering of re-rendered content",
					() => {
						var outdated = createPage(
							format.serialize(
								[
									{
										"type": "heading",
										"id"  : "c1",
										"data": { "text": "Cached", "level": "2" },
										"html": "<h2 class=""old-template"">Cached</h2>"
									}
								]
							)
						);
						try {
							// Rendered once: in ContentBox's content cache now (if caching is on)
							expect( pageService.get( outdated.getContentID() ).renderContent() ).toInclude(
								"old-template"
							);

							rerender.rerenderSite( site, getAdministrator() );

							// ContentBox clears the cache asynchronously
							var rendered = "";
							for ( var i = 1; i <= 30; i++ ) {
								ormClearSession();
								rendered = pageService.get( outdated.getContentID() ).renderContent();
								if ( !find( "old-template", rendered ) ) {
									break;
								}
								sleep( 100 );
							}
							// Any heading markup: the dev site's theme may replace the core heading block
							expect( rendered ).toInclude( ">Cached</h2>" );
							expect( rendered ).notToInclude( "old-template" );
						} finally {
							deletePage( outdated );
						}
					}
				);

				it(
					"saves a new version where an old template's HTML changes and skips content edited outside Studio",
					() => {
						// Rendered by an "old template": consistent hash, but not what the heading template renders today
						var outdated = createPage(
							format.serialize(
								[
									{
										"type": "heading",
										"id"  : "r1",
										"data": { "text": "Old", "level": "2" },
										"html": "<h2 class=""old-template"">Old</h2>"
									}
								]
							)
						);
						// Inner HTML changed after Studio wrote it: hash mismatch
						var edited = createPage(
							replace(
								format.serialize(
									[
										{
											"type": "heading",
											"id"  : "e1",
											"data": { "text": "E" },
											"html": "<h2 class=""cbs-heading"">E</h2>"
										}
									]
								),
								">E</h2>",
								">Edited elsewhere</h2>"
							)
						);
						try {
							var versionsBefore = outdated.getContentVersions().len();

							var result = rerender.rerenderSite( site, getAdministrator() );

							expect( result.checked ).toBeGTE( 2 );
							expect( result.updated ).toInclude( outdated.getSlug() );
							expect( result.skipped.map( ( item ) => item.slug ) ).toInclude( edited.getSlug() );

							var reloaded = pageService.get( outdated.getContentID() );
							// Any heading markup: the dev site's theme may replace the core heading block
							expect( reloaded.getContent() ).toInclude( ">Old</h2>" );
							expect( reloaded.getContent() ).notToInclude( "old-template" );
							expect( reloaded.getContentVersions().len() ).toBe( versionsBefore + 1 );
							expect( pageService.get( edited.getContentID() ).getContent() ).toInclude(
								"Edited elsewhere"
							);
						} finally {
							deletePage( outdated );
							deletePage( edited );
						}
					}
				);

				it(
					"is only allowed with THEME_ADMIN",
					() => {
						withTemporaryAuthor(
							[ "STUDIO_ACCESS" ],
							( author ) => {
								var response = post(
									route  = "/cbstudio/api/blocks/rerender",
									params = { "x-auth-token": tokenFor( author ) }
								);
								expect( renderedStatus( response ) ).toBe( 403 );
							}
						);
					}
				);
			}
		);
	}

	private function createPage( required string body ) {
		var slug = "studio-rerender-#lCase(
			left(
				replace(
					createUUID(),
					"-",
					"",
					"all"
				),
				10
			)
		)#";
		var author = getAdministrator();
		var page = pageService.new(
			{
				"title"        : slug,
				"slug"         : slug,
				"publishedDate": now(),
				"site"         : site,
				"creator"      : author
			}
		);
		// Like the admin: the body is a content version
		page.addNewContentVersion(
			content   = arguments.body,
			changelog = "ContentBox Studio test",
			author    = author
		);
		return pageService.save( page );
	}

	private void function deletePage( required page ) {
		ormClearSession();
		var stored = pageService.get( arguments.page.getContentID() );
		if ( !isNull( stored ) && stored.isLoaded() ) {
			pageService.delete( stored );
		}
	}

}