/**
 * models/tree/SiteTree.cfc and the tree API: listing, moving and ordering pages
 */
component extends="cbstudioTests.resources.StudioBaseTest" {
	variables.MARKER = "cbstudio-tree";

	function run( testResults, testBox ) {
		describe(
			"Site tree",
			() => {
				beforeEach(
					() => {
						setup();
						siteTree = getInstance( "SiteTree@contentbox-studio" );
						pageService = getInstance( "pageService@contentbox" );
						site = getInstance( "siteService@contentbox" ).getDefaultSite();
					}
				);

				afterEach(
					() => {
						deleteTestPages( variables.MARKER );
					}
				);

				it(
					"lists pages with parent, status, blocks flag and URL",
					() => {
						var root = createTestPage( testSlug( variables.MARKER ) );
						var draft = createTestPage(
							testSlug( variables.MARKER ),
							root,
							false
						);
						var scheduled = createTestPage(
							testSlug( variables.MARKER ),
							root,
							true,
							dateAdd(
								"d",
								7,
								now()
							)
						);
						var blocks = createTestPage(
							slug = testSlug( variables.MARKER ),
							body = getInstance( "BlockRenderer@contentbox-studio" ).renderBlocks(
								site,
								[ { "type": "heading", "data": { "text": "x" } } ]
							).body
						);

						var pages = {};
						for ( var page in siteTree.getPages( site ) ) {
							pages[ page.contentID ] = page;
						}

						expect( pages[ root.getContentID() ].status ).toBe( "published" );
						expect( pages[ root.getContentID() ].parentID ).toBe( "" );
						expect( pages[ draft.getContentID() ].status ).toBe( "draft" );
						expect( pages[ draft.getContentID() ].parentID ).toBe( root.getContentID() );
						expect( pages[ scheduled.getContentID() ].status ).toBe( "scheduled" );
						expect( pages[ blocks.getContentID() ].hasBlocks ).toBeTrue();
						expect( pages[ root.getContentID() ].hasBlocks ).toBeFalse();
						expect( pages[ draft.getContentID() ].url ).toInclude( draft.getSlug() );
					}
				);

				it(
					"moves a page with its subpages, updates their slugs and adds relocations",
					() => {
						var target = createTestPage( testSlug( variables.MARKER ) );
						var page = createTestPage( testSlug( variables.MARKER ) );
						var child = createTestPage( testSlug( variables.MARKER ), page );
						var oldChildSlug = child.getSlug();

						var result = siteTree.movePage(
							page,
							target.getContentID(),
							0
						);

						ormClearSession();
						var moved = pageService.get( page.getContentID() );
						expect( moved.getParent().getContentID() ).toBe( target.getContentID() );
						expect( result.slug ).toBe( target.getSlug() & "/" & listLast( result.previousSlug, "/" ) );
						expect( moved.getSlug() ).toBe( result.slug );
						expect( pageService.get( child.getContentID() ).getSlug() ).toBe(
							result.slug & "/" & listLast( oldChildSlug, "/" )
						);
						var relocations = queryExecute(
							"SELECT slug FROM cb_relocations WHERE slug = :slug",
							{ "slug": result.previousSlug }
						);
						expect( relocations.recordCount ).toBe( 1 );
					}
				);

				it(
					"moves a page back to the root",
					() => {
						var parent = createTestPage( testSlug( variables.MARKER ) );
						var page = createTestPage( testSlug( variables.MARKER ), parent );

						var result = siteTree.movePage(
							page,
							"",
							0
						);

						ormClearSession();
						var moved = pageService.get( page.getContentID() );
						expect( isNull( moved.getParent() ) ).toBeTrue();
						expect( moved.getSlug() ).toBe( listLast( result.previousSlug, "/" ) );
					}
				);

				it(
					"orders the new siblings with the page at its position",
					() => {
						var parent = createTestPage( testSlug( variables.MARKER ) );
						var first = createTestPage( testSlug( variables.MARKER ), parent );
						var second = createTestPage( testSlug( variables.MARKER ), parent );
						var page = createTestPage( testSlug( variables.MARKER ) );

						siteTree.movePage(
							page,
							parent.getContentID(),
							1
						);

						ormClearSession();
						var children = pageService
							.newCriteria()
							.isEq( "parent", pageService.get( parent.getContentID() ) )
							.list( sortOrder = "order asc" )
							.map( ( child ) => child.getContentID() );
						expect( children[ 2 ] ).toBe( page.getContentID() );
						expect( children.len() ).toBe( 3 );
					}
				);

				it(
					"refuses to move a page under itself or a subpage, or onto an existing slug",
					() => {
						var page = createTestPage( testSlug( variables.MARKER ) );
						var child = createTestPage( testSlug( variables.MARKER ), page );
						expect(
							() => siteTree.movePage(
								page,
								child.getContentID(),
								0
							)
						).toThrow( "SiteTree.InvalidMove" );
						expect(
							() => siteTree.movePage(
								page,
								page.getContentID(),
								0
							)
						).toThrow( "SiteTree.InvalidMove" );

						var parent = createTestPage( testSlug( variables.MARKER ) );
						var segment = listLast( child.getSlug(), "/" );
						createTestPage( segment, parent );
						ormClearSession();
						expect(
							() => siteTree.movePage(
								pageService.get( child.getContentID() ),
								parent.getContentID(),
								0
							)
						).toThrow( "SiteTree.InvalidMove" );
					}
				);

				describe(
					"API",
					() => {
						it(
							"returns the tree of a site",
							() => {
								var page = createTestPage( testSlug( variables.MARKER ) );
								var response = get(
									route  = "/cbstudio/api/sites/default/tree",
									params = { "x-auth-token": tokenFor( getAdministrator() ) }
								).getResponse();
								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								expect( response.getData().map( ( item ) => item.contentID ) ).toInclude(
									page.getContentID()
								);
							}
						);

						it(
							"moves pages only with STUDIO_SITE_TREE",
							() => {
								var page = createTestPage( testSlug( variables.MARKER ) );
								withTemporaryAuthor(
									[ "STUDIO_ACCESS", "PAGES_EDITOR" ],
									( author ) => {
										var response = post(
											route  = "/cbstudio/api/pages/#page.getContentID()#/move",
											params = {
												"x-auth-token": tokenFor( author ),
												"parentID"    : "",
												"index"       : 0
											}
										);
										expect( renderedStatus( response ) ).toBe( 403 );
									}
								);
							}
						);

						it(
							"reports an invalid move as a conflict",
							() => {
								var page = createTestPage( testSlug( variables.MARKER ) );
								var response = post(
									route  = "/cbstudio/api/pages/#page.getContentID()#/move",
									params = {
										"x-auth-token": tokenFor( getAdministrator() ),
										"parentID"    : page.getContentID(),
										"index"       : 0
									}
								);
								expect( renderedStatus( response ) ).toBe( 409 );
							}
						);
					}
				);
			}
		);
	}

}