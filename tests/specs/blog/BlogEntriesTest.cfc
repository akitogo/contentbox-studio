/**
 * models/blog/BlogEntries.cfc and the blog API: the list of entries for authors, categories, new entries
 */
component extends="cbstudioTests.resources.StudioBaseTest" {
	variables.MARKER = "cbstudio-blog";

	function run( testResults, testBox ) {
		describe(
			"Blog entries",
			() => {
				beforeEach(
					() => {
						setup();
						blog = getInstance( "BlogEntries@contentbox-studio" );
						editor = getInstance( "ContentEditor@contentbox-studio" );
						entryService = getInstance( "entryService@contentbox" );
						// New entries need the default site's blog turned on (a dev site may have it off); afterEach
						// puts the setting back
						blogWasEnabled = isBlogEnabled();
						if ( !blogWasEnabled ) {
							setBlogEnabled( true );
						}
						site = getInstance( "siteService@contentbox" ).getDefaultSite();
					}
				);

				afterEach(
					() => {
						if ( isBlogEnabled() != blogWasEnabled ) {
							setBlogEnabled( blogWasEnabled );
						}
						deleteTestEntries( variables.MARKER );
						deleteTestPages( variables.MARKER );
						queryExecute(
							"DELETE FROM cb_contentTemplate WHERE name LIKE :name",
							{ "name": "%#variables.MARKER#%" }
						);
					}
				);

				it(
					"lists entries newest first with status, author, categories, blocks flag and URL",
					() => {
						var category = createTestCategory( testSlug( variables.MARKER ) );
						var older = createTestEntry(
							slug          = testSlug( variables.MARKER ),
							publishedDate = dateAdd(
								"d",
								-2,
								now()
							),
							categories    = [ category ]
						);
						var newer = createTestEntry(
							slug          = testSlug( variables.MARKER ),
							publishedDate = dateAdd(
								"d",
								-1,
								now()
							)
						);
						var draft = createTestEntry(
							slug          = testSlug( variables.MARKER ),
							isPublished   = false,
							publishedDate = dateAdd(
								"h",
								-1,
								now()
							)
						);
						var blocks = createTestEntry(
							slug = testSlug( variables.MARKER ),
							body = getInstance( "BlockRenderer@contentbox-studio" ).renderBlocks(
								site,
								[ { "type": "heading", "data": { "text": "x" } } ]
							).body
						);

						var result = blog.list( site = site, search = variables.MARKER );

						expect( result.total ).toBe( 4 );
						expect( result.entries.map( ( entry ) => entry.contentID ) ).toBe(
							[ blocks.getContentID(), draft.getContentID(), newer.getContentID(), older.getContentID() ]
						);
						var first = result.entries[ 1 ];
						expect( first.status ).toBe( "published" );
						expect( first.hasBlocks ).toBeTrue();
						expect( first.author ).notToBeEmpty();
						expect( first.url ).toMatch( "/#blocks.getSlug()#$" );
						expect( result.entries[ 2 ].status ).toBe( "draft" );
						expect( result.entries[ 2 ].hasBlocks ).toBeFalse();
						expect( result.entries[ 4 ].categories ).toBe(
							[
								{
									"categoryID": category.getCategoryID(),
									"name"      : category.getCategory(),
									"slug"      : category.getSlug()
								}
							]
						);
						expect( result.entries[ 3 ].categories ).toBeEmpty();
					}
				);

				it(
					"filters by status",
					() => {
						var published = createTestEntry( testSlug( variables.MARKER ) );
						var draft = createTestEntry( slug = testSlug( variables.MARKER ), isPublished = false );
						var scheduled = createTestEntry(
							slug          = testSlug( variables.MARKER ),
							publishedDate = dateAdd(
								"d",
								7,
								now()
							)
						);
						var expired = createTestEntry(
							slug       = testSlug( variables.MARKER ),
							expireDate = dateAdd(
								"d",
								-1,
								now()
							)
						);

						var expected = {
							"published": published,
							"draft"    : draft,
							"scheduled": scheduled,
							"expired"  : expired
						};
						for ( var status in expected ) {
							var result = blog.list(
								site   = site,
								search = variables.MARKER,
								status = status
							);
							expect( result.entries.map( ( entry ) => entry.contentID ) ).toBe(
								[ expected[ status ].getContentID() ],
								status
							);
							expect( result.entries[ 1 ].status ).toBe( status );
						}
					}
				);

				it(
					"filters by category or no category and pages through the results",
					() => {
						var category = createTestCategory( testSlug( variables.MARKER ) );
						var first = createTestEntry(
							slug          = testSlug( variables.MARKER ),
							publishedDate = dateAdd(
								"d",
								-1,
								now()
							),
							categories    = [ category ]
						);
						var second = createTestEntry(
							slug          = testSlug( variables.MARKER ),
							publishedDate = dateAdd(
								"d",
								-2,
								now()
							)
						);
						var third = createTestEntry(
							slug          = testSlug( variables.MARKER ),
							publishedDate = dateAdd(
								"d",
								-3,
								now()
							),
							categories    = [ category ]
						);

						var inCategory = blog.list(
							site     = site,
							search   = variables.MARKER,
							category = category.getCategoryID()
						);
						expect( inCategory.entries.map( ( entry ) => entry.contentID ) ).toBe(
							[ first.getContentID(), third.getContentID() ]
						);

						var withoutCategory = blog.list(
							site     = site,
							search   = variables.MARKER,
							category = "none"
						);
						expect( withoutCategory.entries.map( ( entry ) => entry.contentID ) ).toBe(
							[ second.getContentID() ]
						);

						var page = blog.list(
							site   = site,
							search = variables.MARKER,
							offset = 1,
							max    = 1
						);
						expect( page.total ).toBe( 3 );
						expect( page.offset ).toBe( 1 );
						expect( page.max ).toBe( 1 );
						expect( page.entries.map( ( entry ) => entry.contentID ) ).toBe( [ second.getContentID() ] );
					}
				);

				it(
					"rejects an unknown status",
					() => {
						expect( () => blog.list( site = site, status = "nope" ) ).toThrow(
							"BlogEntries.InvalidFilter"
						);
					}
				);

				it(
					"lists categories with their number of entries",
					() => {
						var used = createTestCategory( testSlug( variables.MARKER ) );
						var unused = createTestCategory( testSlug( variables.MARKER ) );
						createTestEntry(
							slug       = testSlug( variables.MARKER ),
							categories = [ used ]
						);
						createTestEntry(
							slug       = testSlug( variables.MARKER ),
							categories = [ used ]
						);

						var categories = {};
						for ( var category in blog.categories( site ) ) {
							categories[ category.categoryID ] = category;
						}
						expect( categories[ used.getCategoryID() ].entries ).toBe( 2 );
						expect( categories[ used.getCategoryID() ].name ).toBe( used.getCategory() );
						expect( categories[ unused.getCategoryID() ].entries ).toBe( 0 );
					}
				);

				it(
					"creates draft entries with an address from the title and refuses used addresses",
					() => {
						var entry = blog.createEntry(
							site   = site,
							title  = "#variables.MARKER# Hello World #createUUID()#",
							author = getAdministrator()
						);
						ormClearSession();
						var saved = entryService.get( entry.getContentID() );
						expect( saved.getIsPublished() ).toBeFalse();
						expect( saved.getSlug() ).toInclude( "#variables.MARKER#-hello-world" );
						expect( saved.getCreator().getAuthorID() ).toBe( getAdministrator().getAuthorID() );

						expect(
							() => {
								blog.createEntry(
									site   = site,
									title  = "Again",
									slug   = saved.getSlug(),
									author = getAdministrator()
								);
							}
						).toThrow( "BlogEntries.InvalidEntry" );
						expect(
							() => {
								blog.createEntry(
									site   = site,
									title  = " ",
									author = getAdministrator()
								);
							}
						).toThrow( "BlogEntries.InvalidEntry" );
					}
				);

				it(
					"makes one template per content type the default (global)",
					() => {
						var templateService = getInstance( "contentTemplateService@contentbox" );
						var previous = templateService
							.newCriteria()
							.isEq( "site", site )
							.isEq( "contentType", "Entry" )
							.isTrue( "isGlobal" )
							.list()
							.map( ( template ) => template.getTemplateID() );
						try {
							var source = createTestEntry( testSlug( variables.MARKER ) );
							var first = editor.saveAsTemplate(
								content  = source,
								name     = "#variables.MARKER# first",
								author   = getAdministrator(),
								isGlobal = true
							);
							var second = editor.saveAsTemplate(
								content  = source,
								name     = "#variables.MARKER# second",
								author   = getAdministrator(),
								isGlobal = true
							);
							ormClearSession();
							var global = editor
								.templates( site, "entry" )
								.filter( ( template ) => template.isGlobal )
								.map( ( template ) => template.templateID );
							expect( global ).toBe( [ second.templateID ] );
						} finally {
							for ( var id in previous ) {
								var template = templateService.get( id );
								template.setIsGlobal( true );
								templateService.save( template );
							}
						}
					}
				);

				it(
					"creates entries from entry templates only",
					() => {
						var source = createTestEntry( testSlug( variables.MARKER ) );
						editor.save(
							content = source,
							blocks  = [
								{
									"type": "heading",
									"id"  : "t1",
									"data": { "text": "Post heading" }
								}
							],
							author  = getAdministrator()
						);
						ormClearSession();
						var template = editor.saveAsTemplate(
							content = entryService.get( source.getContentID() ),
							name    = "#variables.MARKER# post",
							author  = getAdministrator()
						);
						expect(
							editor
								.templates( site, "entry" )
								.filter( ( item ) => item.templateID == template.templateID )
								.len()
						).toBe( 1 );

						var entry = blog.createEntry(
							site       = site,
							title      = "#variables.MARKER# from template",
							templateID = template.templateID,
							author     = getAdministrator()
						);
						ormClearSession();
						var blocks = getInstance( "BlockFormat@contentbox-studio" ).parse(
							entryService.get( entry.getContentID() ).getContent()
						);
						expect( blocks[ 1 ].data.text ).toBe( "Post heading" );

						var page = createTestPage( testSlug( variables.MARKER ) );
						var pageTemplate = editor.saveAsTemplate(
							content = page,
							name    = "#variables.MARKER# page",
							author  = getAdministrator()
						);
						expect(
							() => {
								blog.createEntry(
									site       = site,
									title      = "#variables.MARKER# from page template",
									templateID = pageTemplate.templateID,
									author     = getAdministrator()
								);
							}
						).toThrow( "BlogEntries.InvalidEntry" );
					}
				);

				it(
					"saves entry settings and the language with the blocks",
					() => {
						var entry = createTestEntry( testSlug( variables.MARKER ) );
						var category = createTestCategory( testSlug( variables.MARKER ) );
						var later = dateAdd(
							"d",
							10,
							now()
						);

						var result = editor.save(
							content  = entry,
							blocks   = [],
							author   = getAdministrator(),
							language = "en",
							entry    = {
								"publishedDate": dateTimeFormat( later, "yyyy-mm-dd'T'HH:nn" ),
								"expireDate"   : "",
								"categories"   : [
									{ "categoryID": category.getCategoryID() },
									{ "name": "#variables.MARKER# News" },
									{ "name": category.getCategory() }
								],
								"excerpt": {
									"type"   : "doc",
									"content": [
										{
											"type"   : "paragraph",
											"content": [ { "type": "text", "text": "Short <b>" } ]
										}
									]
								},
								"featuredImage": "/__media/summer.jpg",
								"allowComments": false
							}
						);

						expect( result.saved ).toBeTrue();
						var details = result.content;
						expect( details.status ).toBe( "scheduled" );
						expect( details.publishedDate ).toBe( dateTimeFormat( later, "yyyy-mm-dd'T'HH:nn:00" ) );
						expect( details.language ).toBe( "en" );
						expect(
							details
								.entry
								.categories
								.map( ( item ) => item.name )
						)// By name (" " sorts before "-"); the category given by id and by name is there once
						.toBe( [ "#variables.MARKER# News", category.getCategory() ] );
						expect( details.entry.categories[ 1 ].slug ).toBe( "#variables.MARKER#-news" );
						expect( details.entry.excerpt ).toBe( "<p>Short &lt;b&gt;</p>" );
						expect( details.entry.featuredImage ).toBe( "/__media/summer.jpg" );
						expect( details.entry.allowComments ).toBeFalse();

						ormClearSession();
						var stored = entryService.get( entry.getContentID() );
						expect( stored.getCategories().len() ).toBe( 2 );
						expect( isNull( stored.getExpireDate() ) ).toBeTrue();
						expect( getInstance( "Translations@contentbox-studio" ).languageOf( stored ) ).toBe( "en" );
					}
				);

				it(
					"refuses invalid entry settings before changing anything",
					() => {
						var entry = createTestEntry( testSlug( variables.MARKER ) );
						var save = ( settings ) => {
							editor.save(
								content = entryService.get( entry.getContentID() ),
								blocks  = [],
								author  = getAdministrator(),
								entry   = settings
							);
						};
						expect(
							() => save(
								{
									"publishedDate": "2026-12-01T10:00",
									"expireDate"   : "2026-11-01T10:00"
								}
							)
						).toThrow( "ContentEditor.Invalid" );
						expect( () => save( { "publishedDate": "2026-02-30T10:00" } ) ).toThrow(
							"ContentEditor.Invalid"
						);
						expect(
							() => save( { "categories": [ { "categoryID": "nope" } ] } )
						).toThrow( "ContentEditor.Invalid" );
						expect( () => save( { "featuredImage": "javascript:alert(1)" } ) ).toThrow(
							"ContentEditor.Invalid"
						);
						expect(
							() => {
								editor.save(
									content = createTestPage( testSlug( variables.MARKER ) ),
									blocks  = [],
									author  = getAdministrator(),
									entry   = {}
								);
							}
						).toThrow( "ContentEditor.Invalid" );

						ormClearSession();
						expect( editor.versions( entryService.get( entry.getContentID() ) ).len() ).toBe( 1 );
					}
				);

				it(
					"needs STUDIO_SITE_TREE to set the language",
					() => {
						var entry = createTestEntry( testSlug( variables.MARKER ) );
						withTemporaryAuthor(
							[ "STUDIO_ACCESS", "ENTRIES_EDITOR" ],
							( author ) => {
								expect(
									() => {
										editor.save(
											content  = entry,
											blocks   = [],
											author   = author,
											language = "de"
										);
									}
								).toThrow( "ContentEditor.Forbidden" );
							}
						);
					}
				);

				describe(
					"API",
					() => {
						it(
							"lists entries and categories and rejects unknown filters",
							() => {
								var entry = createTestEntry( testSlug( variables.MARKER ) );
								var token = tokenFor( getAdministrator() );

								var response = get(
									route  = "/cbstudio/api/sites/default/entries",
									params = { "x-auth-token": token, "search": entry.getSlug() }
								).getResponse();
								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								expect( response.getData().total ).toBe( 1 );
								expect( response.getData().entries[ 1 ].contentID ).toBe( entry.getContentID() );

								setup();
								var categories = get(
									route  = "/cbstudio/api/sites/default/categories",
									params = { "x-auth-token": token }
								).getResponse();
								expect( categories.getStatusCode() ).toBe( 200, categories.getMessagesString() );
								expect( isArray( categories.getData() ) ).toBeTrue();

								setup();
								var invalid = get(
									route  = "/cbstudio/api/sites/default/entries",
									params = { "x-auth-token": token, "status": "nope" }
								);
								expect( renderedStatus( invalid ) ).toBe( 400 );
							}
						);

						it(
							"creates entries and reports used addresses",
							() => {
								var token = tokenFor( getAdministrator() );
								var title = "#variables.MARKER# api #createUUID()#";
								var response = post(
									route  = "/cbstudio/api/sites/default/entries",
									params = { "x-auth-token": token, "title": title }
								).getResponse();
								expect( response.getStatusCode() ).toBe( 201, response.getMessagesString() );
								expect( response.getData().contentID ).notToBeEmpty();

								setup();
								var again = post(
									route  = "/cbstudio/api/sites/default/entries",
									params = { "x-auth-token": token, "title": title }
								);
								expect( renderedStatus( again ) ).toBe( 409 );
							}
						);

						it(
							"refuses new entries while the site's blog is turned off",
							() => {
								var blogOff = createStub().$( "getIsBlogEnabled", false );
								expect(
									() => {
										blog.createEntry(
											site   = blogOff,
											title  = "#variables.MARKER# off",
											author = getAdministrator()
										);
									}
								).toThrow( "BlogEntries.BlogDisabled" );

								setBlogEnabled( false );
								var response = post(
									route  = "/cbstudio/api/sites/default/entries",
									params = {
										"x-auth-token": tokenFor( getAdministrator() ),
										"title"       : "#variables.MARKER# off"
									}
								);
								expect( renderedStatus( response ) ).toBe( 409 );
							}
						);

						it(
							"needs ENTRIES_ADMIN or ENTRIES_EDITOR to create entries",
							() => {
								withTemporaryAuthor(
									[ "STUDIO_ACCESS" ],
									( author ) => {
										var response = post(
											route  = "/cbstudio/api/sites/default/entries",
											params = {
												"x-auth-token": tokenFor( author ),
												"title"       : "#variables.MARKER# nope"
											}
										);
										expect( renderedStatus( response ) ).toBe( 403 );
									}
								);
							}
						);
					}
				);
			}
		);
	}

	/**
	 * Whether the default site's blog is turned on (from the database)
	 */
	private boolean function isBlogEnabled() {
		var rows = queryExecute(
			"SELECT isBlogEnabled FROM cb_site WHERE slug = 'default'"
		);
		return rows.recordCount && rows.isBlogEnabled[ 1 ] == true;
	}

	/**
	 * Turn the default site's blog on or off. In SQL, not by saving the site: sites are in Hibernate's second-level
	 * cache, and specs clear the session, so a saved site instance can clash with a newer one.
	 */
	private function setBlogEnabled( required boolean enabled ) {
		queryExecute(
			"UPDATE cb_site SET isBlogEnabled = :enabled WHERE slug = 'default'",
			{
				"enabled": {
					"value"    : arguments.enabled,
					"cfsqltype": "cf_sql_bit"
				}
			}
		);
		ormEvictEntity( "cbSite" );
		ormClearSession();
	}

}