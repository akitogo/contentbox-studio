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
								var response = get( route = "/cbstudio/api/me" );
								expect( renderedStatus( response ) ).toBe( 401 );
								expect( response.getResponse().getError() ).toBeTrue();
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
										);
										expect( renderedStatus( response ) ).toBe( 403 );
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
					"Blocks",
					() => {
						it(
							"lists the block types of the default site without template paths",
							() => {
								var response = get(
									route  = "/cbstudio/api/blocks",
									params = { "x-auth-token": tokenFor( getAdministrator() ) }
								).getResponse();

								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								var names = response.getData().map( ( type ) => type.name );
								expect( names ).toInclude( "heading" );
								expect( names ).toInclude( "html" );
								expect( response.getData()[ 1 ] ).notToHaveKey( "renderTemplate" );
							}
						);

						it(
							"renders blocks for a preview and reports errors",
							() => {
								var response = post(
									route  = "/cbstudio/api/blocks/render",
									params = {
										"x-auth-token": tokenFor( getAdministrator() ),
										"blocks"      : [
											{
												"type": "heading",
												"id"  : "h1",
												"data": { "text": "Preview" }
											},
											{ "type": "nope", "id": "n1", "data": {} }
										]
									}
								).getResponse();

								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								var data = response.getData();
								expect( data.blocks[ 1 ].html ).toBe( "<h2 class=""cbs-heading"">Preview</h2>" );
								expect( data.body ).toInclude( "<!-- cb:block " );
								expect( data.errors[ 1 ].message ).toInclude( "Unknown block type" );
							}
						);

						it(
							"rejects a render request without blocks",
							() => {
								var response = post(
									route  = "/cbstudio/api/blocks/render",
									params = { "x-auth-token": tokenFor( getAdministrator() ) }
								);
								expect( renderedStatus( response ) ).toBe( 400 );
							}
						);
					}
				);

				describe(
					"GET /cbstudio/api/sites",
					() => {
						it(
							"lists the active sites with whether their blog is turned on",
							() => {
								var response = get(
									route  = "/cbstudio/api/sites",
									params = { "x-auth-token": tokenFor( getAdministrator() ) }
								).getResponse();

								expect( response.getStatusCode() ).toBe( 200, response.getMessagesString() );
								var defaultSite = response.getData().filter( ( site ) => site.slug == "default" );
								expect( defaultSite ).toHaveLength( 1 );
								expect( defaultSite[ 1 ].isBlogEnabled ).toBe(
									getInstance( "siteService@contentbox" ).getDefaultSite().getIsBlogEnabled()
								);
							}
						);
					}
				);
			}
		);
	}

}