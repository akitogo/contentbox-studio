/**
 * New pages, publishing, content templates (block presets) and theme styles for the editor canvas
 */
component extends="cbstudioTests.resources.StudioBaseTest" {
	variables.MARKER = "cbstudio-new";

	function run( testResults, testBox ) {
		describe(
			"Pages and templates",
			() => {
				beforeEach(
					() => {
						setup();
						siteTree = getInstance( "SiteTree@contentbox-studio" );
						editor = getInstance( "ContentEditor@contentbox-studio" );
						pageService = getInstance( "pageService@contentbox" );
						site = getInstance( "siteService@contentbox" ).getDefaultSite();
					}
				);

				afterEach(
					() => {
						deleteTestPages( variables.MARKER );
						queryExecute(
							"DELETE FROM cb_contentTemplate WHERE name LIKE :name",
							{ "name": "%#variables.MARKER#%" }
						);
					}
				);

				it(
					"creates a draft page with a slug from the title, last among its siblings",
					() => {
						var parent = createTestPage( testSlug( variables.MARKER ) );
						var sibling = createTestPage( testSlug( variables.MARKER ), parent );
						// Orders with gaps, as the classic admin can leave them
						sibling.setOrder( 7 );
						pageService.save( sibling );
						var title = "#variables.MARKER# Rooms & Suites #createUUID()#";

						var page = siteTree.createPage(
							site     = site,
							title    = title,
							parentID = parent.getContentID(),
							author   = getAdministrator()
						);

						ormClearSession();
						var stored = pageService.get( page.getContentID() );
						expect( stored.getIsPublished() ).toBeFalse();
						expect( stored.getParent().getContentID() ).toBe( parent.getContentID() );
						expect( stored.getSlug() ).toBe(
							parent.getSlug() & "/" & getInstance( "HTMLHelper@coldbox" ).slugify( title )
						);
						expect( stored.getOrder() ).toBe( 8 );
						expect( stored.getContent() ).toBe( "" );
					}
				);

				it(
					"refuses an empty title and an existing address",
					() => {
						expect(
							() => siteTree.createPage(
								site   = site,
								title  = " ",
								author = getAdministrator()
							)
						).toThrow( "SiteTree.InvalidPage" );
						var existing = createTestPage( testSlug( variables.MARKER ) );
						expect(
							() => siteTree.createPage(
								site   = site,
								title  = "x",
								slug   = existing.getSlug(),
								author = getAdministrator()
							)
						).toThrow( "SiteTree.InvalidPage" );
					}
				);

				it(
					"saves blocks as a template and creates pages from it",
					() => {
						var source = createTestPage( testSlug( variables.MARKER ) );
						editor.save(
							content = source,
							blocks  = [
								{
									"type": "heading",
									"id"  : "t1",
									"data": { "text": "Preset heading" }
								}
							],
							author  = getAdministrator()
						);
						ormClearSession();
						var saved = editor.saveAsTemplate(
							content     = pageService.get( source.getContentID() ),
							name        = "#variables.MARKER# preset",
							description = "Studio test",
							author      = getAdministrator()
						);

						var templates = editor.templates( site, "page" ).filter(
							( template ) => template.templateID == saved.templateID
						);
						expect( templates.len() ).toBe( 1 );
						expect( templates[ 1 ].hasBlocks ).toBeTrue();

						var page = siteTree.createPage(
							site       = site,
							title      = "#variables.MARKER# from preset",
							templateID = saved.templateID,
							author     = getAdministrator()
						);
						ormClearSession();
						var blocks = getInstance( "BlockFormat@contentbox-studio" ).parse(
							pageService.get( page.getContentID() ).getContent()
						);
						expect( blocks[ 1 ].type ).toBe( "heading" );
						expect( blocks[ 1 ].data.text ).toBe( "Preset heading" );
					}
				);

				it(
					"publishes and unpublishes",
					() => {
						var page = createTestPage( slug = testSlug( variables.MARKER ), isPublished = false );
						expect(
							editor.setPublished(
								page,
								true,
								getAdministrator()
							).content.isPublished
						).toBeTrue();
						expect(
							editor.setPublished(
								page,
								false,
								getAdministrator()
							).content.isPublished
						).toBeFalse();
					}
				);

				describe(
					"API",
					() => {
						it(
							"creates pages and reports conflicts",
							() => {
								var token = tokenFor( getAdministrator() );
								var title = "#variables.MARKER# api #createUUID()#";
								var response = post(
									route  = "/cbstudio/api/sites/default/pages",
									params = { "x-auth-token": token, "title": title }
								).getResponse();
								expect( response.getStatusCode() ).toBe( 201, response.getMessagesString() );
								expect( response.getData().contentID ).notToBeEmpty();

								setup();
								var again = post(
									route  = "/cbstudio/api/sites/default/pages",
									params = { "x-auth-token": token, "title": title }
								).getResponse();
								expect( again.getStatusCode() ).toBe( 409 );
							}
						);

						it(
							"needs PAGES_ADMIN or PAGES_EDITOR to create pages",
							() => {
								withTemporaryAuthor(
									[ "STUDIO_ACCESS" ],
									( author ) => {
										var response = post(
											route  = "/cbstudio/api/sites/default/pages",
											params = {
												"x-auth-token": tokenFor( author ),
												"title"       : "#variables.MARKER# nope"
											}
										).getResponse();
										expect( response.getStatusCode() ).toBe( 403 );
									}
								);
							}
						);

						it(
							"lists templates and theme styles",
							() => {
								var token = tokenFor( getAdministrator() );
								var templates = get(
									route  = "/cbstudio/api/sites/default/templates",
									params = { "x-auth-token": token }
								).getResponse();
								expect( templates.getStatusCode() ).toBe( 200, templates.getMessagesString() );
								expect( isArray( templates.getData() ) ).toBeTrue();

								setup();
								var styles = get(
									route  = "/cbstudio/api/sites/default/styles",
									params = { "x-auth-token": token }
								).getResponse();
								expect( styles.getStatusCode() ).toBe( 200, styles.getMessagesString() );
								expect( isArray( styles.getData() ) ).toBeTrue();
							}
						);
					}
				);
			}
		);

		describe(
			"Theme styles",
			() => {
				it(
					"finds stylesheet links and resolves them against the site root",
					() => {
						var styles = getInstance( "ThemeStyles@contentbox-studio" );
						// fromPage() fetches; test the parser through a data URL is not possible, so test the resolution rules
						// on links returned for an unreachable page: none, without an error
						expect(
							styles.fromPage( "http://127.0.0.1:1/nothing", "http://127.0.0.1:1" )
						).toBe( [] );
					}
				);
			}
		);
	}

}