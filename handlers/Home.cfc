/**
 * Serves the Studio app. Secured by the module's cbsecurity rule (classic admin session + STUDIO_ACCESS).
 */
component {
	property name="assets" inject="StudioAssets@contentbox-studio";

	property name="securityService" inject="securityService@contentbox";

	function index( event, rc, prc ) {
		// The page carries tokens for the logged-in author: never cache it
		event.setHTTPHeader( name = "Cache-Control", value = "no-store" );

		var author = variables.securityService.getAuthorSession();

		// Read by ui/src/config.ts
		prc.studioConfig = {
			"version"      : getModuleConfig( "contentbox-studio" ).version,
			"studioApi"    : event.buildLink( "cbstudio/api" ),
			"contentboxApi": event.buildLink( "cbapi/v1" ),
			"adminUrl"     : event.buildLink( "cbadmin" ),
			"logoutUrl"    : event.buildLink( "cbadmin/security/doLogout" ),
			"tokens"       : jwtAuth().fromUser( author )
		};

		try {
			prc.assetTags = variables.assets.getTags( event.getModuleRoot( "contentbox-studio" ) );
		} catch (StudioNotBuilt e) {
			event.setHTTPHeader( statusCode = 503 );
			return "<h1>ContentBox Studio is not built</h1><p>#encodeForHTML( e.message )#</p>";
		}

		event.setView( view = "home/index", noLayout = true );
	}

	/**
	 * Logged in, but without the STUDIO_ACCESS permission
	 */
	function noAccess( event, rc, prc ) {
		event.setHTTPHeader( statusCode = 403 );
		prc.author = variables.securityService.getAuthorSession();
		prc.adminUrl = event.buildLink( "cbadmin" );
		event.setView( view = "home/noAccess", noLayout = true );
	}

}