/**
 * The header of blog entries in the editor canvas (models/editor/CanvasHeader.cfc, POST
 * /cbstudio/api/content/:contentID/header) and saving the title
 */
component extends="cbstudioTests.resources.StudioBaseTest" {
	variables.MARKER = "cbstudio-header";

	function run( testResults, testBox ) {
		describe(
			"Canvas header of blog entries",
			() => {
				beforeEach(
					() => {
						setup();
						header = getInstance( "CanvasHeader@contentbox-studio" );
						editor = getInstance( "ContentEditor@contentbox-studio" );
					}
				);

				afterEach(
					() => {
						deleteTestEntries( variables.MARKER );
						deleteTestPages( variables.MARKER );
					}
				);

				it(
					"renders the entry's title, date, author, categories and image, with the title editable in place",
					() => {
						var entry = createTestEntry( testSlug( variables.MARKER ) );
						var html = header.render(
							entry,
							{
								"title"        : "A new title & more",
								"publishedDate": "2026-03-05T10:30",
								"categories"   : [ "Design", " ", "Product" ],
								"featuredImage": "/__media/header-test.png"
							}
						).html;
						// Any theme's markup: the dev site's theme may have its own header template
						expect( html ).toInclude( "A new title &amp; more" );
						expect( html ).toInclude( "data-cbs-field=""title""" );
						// Formatted like ContentBox's display dates (the month's abbreviation depends on the engine's locale)
						expect( html ).toInclude(
							dateFormat(
								createDate(
									2026,
									3,
									5
								),
								entry.DATE_FORMAT
							)
						);
						expect( html ).toInclude( entry.getAuthorName() );
						expect( html ).toInclude( "Design" );
						expect( html ).toInclude( "Product" );
						expect( html ).toInclude( "/__media/header-test.png" );

						// Without values: the entry's own
						expect( header.render( entry ).html ).toInclude( entry.getTitle() );
					}
				);

				it(
					"has no header for pages and uses the theme's template when it has one",
					() => {
						var page = createTestPage( slug = testSlug( variables.MARKER ) );
						expect( header.render( page ).html ).toBe( "" );

						expect(
							header.templateFor(
								{
									"name"       : "fixture",
									"path"       : expandPath( "/cbstudioTests/fixtures/themes" ),
									"includePath": "/cbstudioTests/fixtures/themes/fixture"
								}
							)
						).toBe(
							"/cbstudioTests/fixtures/themes/fixture/blocks/_canvas/entry.cfm"
						);
						expect(
							header.templateFor(
								{
									"name"       : "none",
									"path"       : expandPath( "/cbstudioTests/fixtures/themes" ),
									"includePath": "/cbstudioTests/fixtures/themes/none"
								}
							)
						).toBe( "/contentbox-studio/blocks/_canvas/entry.cfm" );
					}
				);

				it(
					"saves the title, which may not be empty or longer than ContentBox allows",
					() => {
						var entry = createTestEntry( testSlug( variables.MARKER ) );
						var slug = entry.getSlug();
						var blocks = [
							{
								"type": "heading",
								"id"  : "t1",
								"data": { "text": "Body" }
							}
						];
						var result = editor.save(
							content = entry,
							blocks  = blocks,
							author  = getAdministrator(),
							title   = "  #variables.MARKER# renamed  "
						);
						expect( result.content.title ).toBe( "#variables.MARKER# renamed" );
						expect( result.content.slug ).toBe( slug );

						for ( var title in [ "   ", repeatString( "x", 201 ) ] ) {
							expect(
								() => {
									editor.save(
										content = entry,
										blocks  = blocks,
										author  = getAdministrator(),
										title   = title
									);
								}
							).toThrow( "ContentEditor.Invalid" );
						}
					}
				);

				it(
					"renders the header through the API",
					() => {
						var entry = createTestEntry( testSlug( variables.MARKER ) );
						var response = post(
							route  = "/cbstudio/api/content/#entry.getContentID()#/header",
							params = {
								"x-auth-token": tokenFor( getAdministrator() ),
								"title"       : "Via the API",
								"categories"  : [ "Events" ]
							}
						).getResponse();
						expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
						expect( response.getData().html ).toInclude( "Via the API" );
						expect( response.getData().html ).toInclude( "Events" );
					}
				);
			}
		);
	}

}