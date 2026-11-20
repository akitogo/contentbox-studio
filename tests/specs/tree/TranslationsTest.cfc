/**
 * Translation groups (models/tree/Translations.cfc), hreflang links and the translations API
 */
component extends="cbstudioTests.resources.StudioBaseTest" {
	variables.MARKER = "cbstudio-i18n";

	function run( testResults, testBox ) {
		describe(
			"Translation groups",
			() => {
				beforeEach(
					() => {
						setup();
						translations = getInstance( "Translations@contentbox-studio" );
						pageService = getInstance( "pageService@contentbox" );
					}
				);

				afterEach(
					() => {
						deleteTestPages( variables.MARKER );
					}
				);

				it(
					"stores languages and refuses invalid codes",
					() => {
						var page = createTestPage( testSlug( variables.MARKER ) );
						translations.setLanguage( page, "en-GB" );
						expect( translations.forContent( page ).language ).toBe( "en-GB" );
						expect( () => translations.setLanguage( page, "english" ) ).toThrow( "Translations.Invalid" );
					}
				);

				it(
					"links content into a group with every member and its URL",
					() => {
						var german = createTestPage( testSlug( variables.MARKER ) );
						var english = createTestPage( testSlug( variables.MARKER ) );
						var french = createTestPage( testSlug( variables.MARKER ) );
						translations.setLanguage( german, "de" );
						translations.setLanguage( english, "en" );
						translations.setLanguage( french, "fr" );

						translations.link( german, english );
						translations.link( french, german );

						ormClearSession();
						var group = translations.forContent( pageService.get( english.getContentID() ) );
						expect( len( group.group ) ).toBeGT( 0 );
						expect( group.members.len() ).toBe( 3 );
						var languages = group.members.map( ( member ) => member.language );
						languages.sort( "text" );
						expect( languages ).toBe( [ "de", "en", "fr" ] );
						expect(
							group
								.members
								.filter( ( member ) => member.isCurrent )
								.len()
						).toBe( 1 );
						expect( group.members[ 1 ].url ).toInclude( "cbstudio-i18n" );
					}
				);

				it(
					"allows each language once per group",
					() => {
						var one = createTestPage( testSlug( variables.MARKER ) );
						var two = createTestPage( testSlug( variables.MARKER ) );
						translations.setLanguage( one, "de" );
						translations.setLanguage( two, "de" );
						expect( () => translations.link( one, two ) ).toThrow( "Translations.Invalid" );
					}
				);

				it(
					"links only content of the same site",
					() => {
						var page = createTestPage( testSlug( variables.MARKER ) );
						var otherSite = createStub().$( "getSiteID", "another-site" );
						var elsewhere = createStub()
							.$( "getContentID", "elsewhere" )
							.$( "getContentType", "Page" )
							.$( "getSite", otherSite );
						expect( () => translations.link( page, elsewhere ) ).toThrow(
							type = "Translations.Invalid",
							regex = "same site"
						);
						expect( translations.forContent( page ).group ).toBe( "" );
					}
				);

				it(
					"dissolves a group of two when one leaves it",
					() => {
						var one = createTestPage( testSlug( variables.MARKER ) );
						var two = createTestPage( testSlug( variables.MARKER ) );
						translations.link( one, two );
						translations.unlink( one );
						ormClearSession();
						expect( translations.forContent( pageService.get( two.getContentID() ) ).group ).toBe( "" );
					}
				);

				it(
					"adds hreflang links to the head of grouped pages",
					() => {
						var german = createTestPage( testSlug( variables.MARKER ) );
						var english = createTestPage( testSlug( variables.MARKER ) );
						translations.setLanguage( german, "de" );
						translations.setLanguage( english, "en" );
						translations.link( german, english );
						ormClearSession();

						var event = getRequestContext();
						event.setPrivateValue( "page", pageService.get( german.getContentID() ) );
						var buffer = createObject( "java", "java.lang.StringBuilder" ).init();
						getController()
							.getInterceptorService()
							.getInterceptor( "Translations@contentbox-studio" )
							.cbui_beforeHeadEnd(
								event,
								{},
								buffer
							);

						expect( buffer.toString() ).toInclude( "hreflang=""de""" );
						expect( buffer.toString() ).toInclude( "hreflang=""en""" );
						expect( buffer.toString() ).toInclude( english.getSlug() );
					}
				);

				it(
					"links translations through the API",
					() => {
						var one = createTestPage( testSlug( variables.MARKER ) );
						var two = createTestPage( testSlug( variables.MARKER ) );
						var token = tokenFor( getAdministrator() );

						var response = put(
							route  = "/cbstudio/api/content/#one.getContentID()#/language",
							params = { "x-auth-token": token, "language": "de" }
						).getResponse();
						expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );

						setup();
						response = post(
							route  = "/cbstudio/api/content/#one.getContentID()#/translations",
							params = {
								"x-auth-token" : token,
								"translationID": two.getContentID()
							}
						).getResponse();
						expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
						expect(
							response
								.getData()
								.members
								.len()
						).toBe( 2 );
					}
				);
			}
		);
	}

}