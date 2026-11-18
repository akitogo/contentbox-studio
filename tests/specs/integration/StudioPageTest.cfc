/**
 * The Studio page at /cbstudio (handlers/Home.cfc): classic admin session + STUDIO_ACCESS
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"The Studio page",
			() => {
				beforeEach(
					() => {
						setup();
						getSecurityService().logout();
					}
				);

				afterEach(
					() => {
						getSecurityService().logout();
					}
				);

				it(
					"sends visitors who are not logged in to the admin login",
					() => {
						var event = get( route = "/cbstudio" );
						expect( event ).toRedirectTo( "cbadmin/security/login" );
					}
				);

				it(
					"renders the app with JWT tokens for an author with STUDIO_ACCESS",
					() => {
						getSecurityService().login( getAdministrator() );

						var event = get( route = "/cbstudio" );
						var html = event.getRenderedContent();

						var found = reFind(
							"<script type=""application/json"" id=""cbstudio-config"">(.*?)</script>",
							html,
							1,
							true
						);
						expect( found.pos[ 1 ] ).toBeGT( 0, "config script element missing" );

						var config = deserializeJSON( found.match[ 2 ] );
						expect( config.tokens.access_token ).notToBeEmpty();
						expect( config.tokens.refresh_token ).notToBeEmpty();
						expect( config.studioApi ).toInclude( "/cbstudio/api" );
						expect( config.contentboxApi ).toInclude( "/cbapi/v1" );
						expect( html ).toInclude( "/dist/assets/" );
					}
				);

				it(
					"explains a missing STUDIO_ACCESS permission instead of rendering the app",
					() => {
						withAuthorWithoutStudioAccess(
							( author ) => {
								getSecurityService().login( author );

								var event = get( route = "/cbstudio" );

								expect( event.getCurrentEvent() ).toBe( "contentbox-studio:home.noAccess" );
								expect( event.getRenderedContent() ).toInclude( "STUDIO_ACCESS" );
								expect( event.getRenderedContent() ).notToInclude( "cbstudio-config" );
							}
						);
					}
				);
			}
		);
	}

}