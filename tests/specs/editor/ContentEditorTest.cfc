/**
 * Loading and saving content blocks (models/editor/ContentEditor.cfc), versions, media and the editor API
 */
component extends="cbstudioTests.resources.StudioBaseTest" {
	variables.MARKER = "cbstudio-editor";

	function run( testResults, testBox ) {
		describe(
			"Content editor",
			() => {
				beforeEach(
					() => {
						setup();
						editor = getInstance( "ContentEditor@contentbox-studio" );
						pageService = getInstance( "pageService@contentbox" );
					}
				);

				afterEach(
					() => {
						deleteTestPages( variables.MARKER );
					}
				);

				it(
					"loads a page written in the classic editor as one HTML block",
					() => {
						var page = createTestPage(
							slug = testSlug( variables.MARKER ),
							body = "<p>Classic</p>"
						);
						var loaded = editor.load( page, getAdministrator() );
						expect( loaded.canEdit ).toBeTrue();
						expect( loaded.canEditHtml ).toBeTrue();
						expect( loaded.content.contentType ).toBe( "page" );
						expect( loaded.content.version ).toBe( 1 );
						expect( loaded.blocks.len() ).toBe( 1 );
						expect( loaded.blocks[ 1 ].type ).toBe( "html" );
						expect( loaded.blocks[ 1 ].status ).toBe( "legacy" );
					}
				);

				it(
					"saves blocks as a new version",
					() => {
						var page = createTestPage( slug = testSlug( variables.MARKER ) );
						var result = editor.save(
							content     = page,
							blocks      = [
								{
									"type": "heading",
									"id"  : "h1",
									"data": { "text": "Saved" }
								}
							],
							changelog   = "Studio test",
							author      = getAdministrator(),
							baseVersion = 1
						);
						expect( result.saved ).toBeTrue();
						expect( result.content.version ).toBe( 2 );
						expect( result.blocks[ 1 ].id ).toBe( "h1" );

						ormClearSession();
						var stored = pageService.get( page.getContentID() );
						expect( stored.getContent() ).toInclude( "<!-- cb:block " );
						expect( stored.getContent() ).toInclude( "<h2 class=""cbs-heading"">Saved</h2>" );
						var versions = editor.versions( stored );
						expect( versions[ 1 ].version ).toBe( 2 );
						expect( versions[ 1 ].changelog ).toBe( "Studio test" );
						expect( editor.version( stored, versions[ 2 ].versionID ).blocks[ 1 ].type ).toBe( "html" );
					}
				);

				it(
					"lets ContentBox clear its cached rendering of the content after a save",
					() => {
						var page = createTestPage( slug = testSlug( variables.MARKER ) );
						// A block body: Adobe ColdFusion 2023 cannot parse "=> [ ... ]"
						var heading = ( text ) => {
							return [
								{
									"type": "heading",
									"id"  : "h1",
									"data": { "text": text }
								}
							];
						};
						editor.save(
							content = page,
							blocks  = heading( "First text" ),
							author  = getAdministrator()
						);
						ormClearSession();
						var stored = pageService.get( page.getContentID() );
						// Rendered once: in ContentBox's content cache now (if caching is on)
						expect( stored.renderContent() ).toInclude( "First text" );

						editor.save(
							content = stored,
							blocks  = heading( "Second text" ),
							author  = getAdministrator()
						);
						// ContentBox clears the cache asynchronously
						var rendered = "";
						for ( var i = 1; i <= 30; i++ ) {
							ormClearSession();
							rendered = pageService.get( page.getContentID() ).renderContent();
							if ( rendered contains "Second text" ) {
								break;
							}
							sleep( 100 );
						}
						expect( rendered ).toInclude( "Second text" );
					}
				);

				it(
					"saves the SEO fields, without a new version when the blocks stay the same",
					() => {
						var page = createTestPage( slug = testSlug( variables.MARKER ) );
						var blocks = [
							{
								"type": "heading",
								"id"  : "h1",
								"data": { "text": "Rooms" }
							}
						];
						expect(
							editor.save(
								content = page,
								blocks  = blocks,
								author  = getAdministrator()
							).content.version
						).toBe( 2 );

						var result = editor.save(
							content = page,
							blocks  = blocks,
							author  = getAdministrator(),
							seo     = {
								"title"      : "  Rooms by the sea  ",
								"description": "Quiet rooms with a view.",
								"keywords"   : "rooms, sea"
							}
						);
						expect( result.saved ).toBeTrue();
						expect( result.content.version ).toBe( 2 );
						expect( result.content.seo ).toBe(
							{
								"title"      : "Rooms by the sea",
								"description": "Quiet rooms with a view.",
								"keywords"   : "rooms, sea"
							}
						);

						ormClearSession();
						var stored = pageService.get( page.getContentID() );
						expect( stored.getHTMLTitle() ).toBe( "Rooms by the sea" );
						expect( editor.versions( stored ).len() ).toBe( 2 );

						// Without seo the fields stay as they are
						editor.save(
							content = stored,
							blocks  = blocks,
							author  = getAdministrator()
						);
						ormClearSession();
						expect( pageService.get( page.getContentID() ).getHTMLDescription() ).toBe(
							"Quiet rooms with a view."
						);

						expect(
							() => {
								editor.save(
									content = pageService.get( page.getContentID() ),
									blocks  = blocks,
									author  = getAdministrator(),
									seo     = { "description": repeatString( "x", 161 ) }
								);
							}
						).toThrow( "ContentEditor.Invalid" );
					}
				);

				it(
					"refuses a save based on an older version",
					() => {
						var page = createTestPage( slug = testSlug( variables.MARKER ) );
						expect(
							() => editor.save(
								content     = page,
								blocks      = [],
								author      = getAdministrator(),
								baseVersion = 7
							)
						).toThrow( "ContentEditor.Conflict" );
					}
				);

				it(
					"returns validation errors without saving",
					() => {
						var page = createTestPage( slug = testSlug( variables.MARKER ) );
						var result = editor.save(
							content = page,
							blocks  = [
								{
									"type": "heading",
									"id"  : "h1",
									"data": { "text": "" }
								}
							],
							author  = getAdministrator()
						);
						expect( result.saved ).toBeFalse();
						expect( result.errors[ 1 ].blockID ).toBe( "h1" );
						ormClearSession();
						expect( pageService.get( page.getContentID() ).getContent() ).notToInclude( "cb:block" );
					}
				);

				it(
					"lets authors without STUDIO_HTML_BLOCKS keep but not change HTML blocks",
					() => {
						var page = createTestPage(
							slug = testSlug( variables.MARKER ),
							body = "<p>Legacy</p>"
						);
						withTemporaryAuthor(
							[ "STUDIO_ACCESS", "PAGES_EDITOR" ],
							( author ) => {
								// The author's versions must be gone before the author is deleted
								try {
									var kept = editor.save(
										content = page,
										blocks  = [
											{
												"type": "html",
												"id"  : "legacy-1",
												"data": { "html": "<p>Legacy</p>" }
											},
											{
												"type": "heading",
												"id"  : "h1",
												"data": { "text": "New" }
											}
										],
										author  = author
									);
									expect( kept.saved ).toBeTrue();

									ormClearSession();
									var reloaded = pageService.get( page.getContentID() );
									expect(
										() => editor.save(
											content = reloaded,
											blocks  = [
												{
													"type": "html",
													"id"  : "legacy-1",
													"data": { "html": "<script>alert(1)</script>" }
												}
											],
											author  = author
										)
									).toThrow( "ContentEditor.Forbidden" );
									expect(
										() => editor.save(
											content = reloaded,
											blocks  = [
												{
													"type": "html",
													"id"  : "x2",
													"data": { "html": "<p>new</p>" }
												}
											],
											author  = author
										)
									).toThrow( "ContentEditor.Forbidden" );
								} finally {
									deleteTestPages( variables.MARKER );
								}
							}
						);
					}
				);

				describe(
					"API",
					() => {
						it(
							"loads and saves content",
							() => {
								var page = createTestPage( slug = testSlug( variables.MARKER ) );
								var token = tokenFor( getAdministrator() );

								var loaded = get(
									route  = "/cbstudio/api/content/#page.getContentID()#",
									params = { "x-auth-token": token }
								).getResponse();
								expect( loaded.getStatusCode() ).toBe( 200, loaded.getMessagesString() );
								expect( loaded.getData().content.version ).toBe( 1 );

								setup();
								var saved = put(
									route  = "/cbstudio/api/content/#page.getContentID()#/blocks",
									params = {
										"x-auth-token": token,
										"baseVersion" : 1,
										"blocks"      : [
											{
												"type": "heading",
												"id"  : "h1",
												"data": { "text": "Via API" }
											}
										]
									}
								).getResponse();
								expect( saved.getStatusCode() ).toBe( 200, saved.getMessagesString() );
								expect( saved.getData().content.version ).toBe( 2 );

								setup();
								var staleEvent = put(
									route  = "/cbstudio/api/content/#page.getContentID()#/blocks",
									params = { "x-auth-token": token, "baseVersion": 1, "blocks": [] }
								);
								expect( renderedStatus( staleEvent ) ).toBe( 409 );

								setup();
								var invalidEvent = put(
									route  = "/cbstudio/api/content/#page.getContentID()#/blocks",
									params = {
										"x-auth-token": token,
										"blocks"      : [ { "type": "heading", "id": "h1", "data": {} } ]
									}
								);
								expect( renderedStatus( invalidEvent ) ).toBe( 422 );
								expect(
									invalidEvent.getRenderData()
										.data
										.data
										.errors
								).notToBeEmpty();
							}
						);

						it(
							"answers 404 for content that does not exist",
							() => {
								var event = get(
									route  = "/cbstudio/api/content/0000doesnotexist0000",
									params = { "x-auth-token": tokenFor( getAdministrator() ) }
								);
								// What goes over the wire, not only prc.response
								expect( renderedStatus( event ) ).toBe( 404 );
								var rendered = event.getRenderData().data;
								expect( rendered.error ).toBeTrue();
								expect( arrayToList( rendered.messages ) ).toInclude( "not found" );
							}
						);

						it(
							"refuses saves without the content type's permission",
							() => {
								var page = createTestPage( slug = testSlug( variables.MARKER ) );
								withTemporaryAuthor(
									[ "STUDIO_ACCESS" ],
									( author ) => {
										var response = put(
											route  = "/cbstudio/api/content/#page.getContentID()#/blocks",
											params = { "x-auth-token": tokenFor( author ), "blocks": [] }
										);
										expect( renderedStatus( response ) ).toBe( 403 );
									}
								);
							}
						);

						it(
							"publishes and unpublishes through the API",
							() => {
								var page = createTestPage( slug = testSlug( variables.MARKER ), isPublished = false );
								var token = tokenFor( getAdministrator() );
								for ( var state in [ true, false ] ) {
									setup();
									var response = put(
										route  = "/cbstudio/api/content/#page.getContentID()#/status",
										params = { "x-auth-token": token, "isPublished": state }
									).getResponse();
									expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
									expect( response.getData().content.isPublished ).toBe( state );
								}
							}
						);

						it(
							"lets editors save but not publish (the admin permission does)",
							() => {
								var page = createTestPage( slug = testSlug( variables.MARKER ), isPublished = false );
								expect( editor.load( page, getAdministrator() ).canPublish ).toBeTrue();
								withTemporaryAuthor(
									[ "STUDIO_ACCESS", "PAGES_EDITOR" ],
									( author ) => {
										var loaded = editor.load( page, author );
										expect( loaded.canEdit ).toBeTrue();
										expect( loaded.canPublish ).toBeFalse();
										var response = put(
											route  = "/cbstudio/api/content/#page.getContentID()#/status",
											params = { "x-auth-token": tokenFor( author ), "isPublished": true }
										);
										expect( renderedStatus( response ) ).toBe( 403 );
									}
								);
								ormClearSession();
								expect( pageService.get( page.getContentID() ).getIsPublished() ).toBeFalse();
							}
						);

						it(
							"lists content store items of a site",
							() => {
								var response = get(
									route  = "/cbstudio/api/sites/default/contentstore",
									params = { "x-auth-token": tokenFor( getAdministrator() ) }
								).getResponse();
								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								expect( isArray( response.getData() ) ).toBeTrue();
							}
						);
					}
				);
			}
		);

		describe(
			"Media library",
			() => {
				beforeEach(
					() => {
						media = getInstance( "MediaLibrary@contentbox-studio" );
						folder = testSlug( "cbstudio-media" );
						root = getInstance( "mediaService@contentbox" ).getCoreMediaRoot( absolute = true );
					}
				);

				afterEach(
					() => {
						if ( directoryExists( root & "/" & folder ) ) {
							directoryDelete( root & "/" & folder, true );
						}
					}
				);

				it(
					"stores uploads with a clean name and lists them",
					() => {
						var source = getTempDirectory() & createUUID() & ".tmp";
						fileWrite( source, "not really a png" );

						var stored = media.store(
							source,
							"My Photo (1).PNG",
							folder
						);

						expect( stored.name ).toBe( "my-photo-1.png" );
						expect( stored.url ).toBe( "/__media/#folder#/my-photo-1.png" );
						expect( stored.isImage ).toBeTrue();
						expect( fileExists( source ) ).toBeFalse();
						var listed = media.list( folder );
						expect( listed.files.map( ( file ) => file.name ) ).toBe( [ "my-photo-1.png" ] );
					}
				);

				it(
					"refuses other file types and deletes the upload",
					() => {
						var source = getTempDirectory() & createUUID() & ".tmp";
						fileWrite( source, "<svg onload=""alert(1)""/>" );
						expect(
							() => media.store(
								source,
								"logo.svg",
								folder
							)
						).toThrow( "MediaLibrary.Refused" );
						expect( fileExists( source ) ).toBeFalse();
					}
				);

				it(
					"never leaves the media root",
					() => {
						expect( () => media.list( "../.." ) ).toThrow( "MediaLibrary.Refused" );
						expect( () => media.list( "a/../../b" ) ).toThrow( "MediaLibrary.Refused" );
						expect( media.list( "" ).folder ).toBe( "" );
					}
				);
			}
		);
	}

}