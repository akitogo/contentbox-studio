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

		var studioModule = getModuleConfig( "contentbox-studio" );
		var moduleRoot = event.getModuleRoot( "contentbox-studio" );
		var blockStyles = studioModule.settings.coreBlockStyles
			? moduleRoot & "/includes/blocks.css?v=" & studioModule.version
			: "";

		// Read by ui/src/config.ts
		prc.studioConfig = {
			"version"      : studioModule.version,
			// Base styles of the core blocks for the editor canvas ("" when the theme styles them)
			"blockStyles"  : blockStyles,
			"appBase"      : event.buildLink( "cbstudio" ),
			"studioApi"    : event.buildLink( "cbstudio/api" ),
			"contentboxApi": event.buildLink( "cbapi/v1" ),
			"adminUrl"     : event.buildLink( "cbadmin" ),
			"logoutUrl"    : event.buildLink( "cbadmin/security/doLogout" ),
			"tokens"       : jwtAuth().fromUser( author ),
			// ContentBox's /__page_preview and /__entry_preview check this (hash of the author id)
			"previewHash"  : hash( author.getAuthorID() ),
			"pagePreview"  : event.buildLink( "__page_preview" ),
			"entryPreview" : event.buildLink( "__entry_preview" )
		};

		try {
			prc.assetTags = variables.assets.getTags( moduleRoot );
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