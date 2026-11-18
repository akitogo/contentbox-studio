/**
 * The Studio API at /cbstudio/api (modules/contentbox-studio-api): JWT + STUDIO_ACCESS
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"The Studio API",
			() => {
				beforeEach(
					() => {
						setup();
					}
				);

				describe(
					"GET /cbstudio/api/me",
					() => {
						it(
							"rejects requests without a token",
							() => {
								var response = get( route = "/cbstudio/api/me" ).getResponse();
								expect( response.getStatusCode() ).toBe( 401 );
								expect( response.getError() ).toBeTrue();
							}
						);

						it(
							"rejects an author without STUDIO_ACCESS",
							() => {
								withAuthorWithoutStudioAccess(
									( author ) => {
										var response = get(
											route  = "/cbstudio/api/me",
											params = { "x-auth-token": tokenFor( author ) }
										).getResponse();
										expect( response.getStatusCode() ).toBe( 403 );
									}
								);
							}
						);

						it(
							"returns the author and their Studio permissions",
							() => {
								var administrator = getAdministrator();

								var response = get(
									route  = "/cbstudio/api/me",
									params = { "x-auth-token": tokenFor( administrator ) }
								).getResponse();

								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								var data = response.getData();
								expect( data.authorID ).toBe( administrator.getAuthorID() );
								expect( data.role ).toBe( "Administrator" );
								expect( data.permissions.siteTree ).toBeTrue();
								expect( data.permissions.htmlBlocks ).toBeTrue();
							}
						);
					}
				);

				describe(
					"GET /cbstudio/api/sites",
					() => {
						it(
							"lists the active sites",
							() => {
								var response = get(
									route  = "/cbstudio/api/sites",
									params = { "x-auth-token": tokenFor( getAdministrator() ) }
								).getResponse();

								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								var slugs = response.getData().map( ( site ) => site.slug );
								expect( slugs ).toInclude( "default" );
							}
						);
					}
				);
			}
		);
	}

}