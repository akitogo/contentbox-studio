/**
 * Conversion tool: copy a site, and turn the HTML of a site's content into blocks with a conversion profile
 * (models/convert/). Needs STUDIO_CONVERT (administrators); copying a site also needs SITES_ADMIN.
 */
component extends="BaseHandler" {
	property name="pageConverter" inject="PageConverter@contentbox-studio";

	property name="profiles" inject="Profiles@contentbox-studio";

	property name="siteCopy" inject="SiteCopy@contentbox-studio";

	property name="themeService" inject="themeService@contentbox";
	this.allowedMethods = {
		"index" : "GET",
		"report": "GET",
		"apply" : "POST",
		"copy"  : "POST"
	};

	/**
	 * GET /cbstudio/api/convert: the profiles and the themes a copy can use
	 *
	 * @return { profiles: [ { name, label, theme, compare, problems } ], themes: [ { name, label } ] }
	 */
	function index( event, rc, prc ) secured="STUDIO_CONVERT" {
		var themes = [];
		var registry = variables.themeService.getThemes();
		for ( var name in registry ) {
			themes.append( { "name": name, "label": registry[ name ].themeName ?: name } );
		}
		themes.sort( ( a, b ) => compareNoCase( a.label, b.label ) );
		prc.response.setData( { "profiles": variables.profiles.list(), "themes": themes } );
	}

	/**
	 * GET /cbstudio/api/sites/:site/convert?profile=&contentID=: dry run (contentID: one item, with each part's HTML)
	 */
	function report( event, rc, prc ) secured="STUDIO_CONVERT" {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		try {
			prc.response.setData(
				variables.pageConverter.report(
					site,
					text( rc.profile ?: "" ),
					text( rc.contentID ?: "" )
				)
			);
		} catch ( Convert.ProfileNotFound e ) {
			prc.response.setErrorMessage( e.message, 404 );
		} catch ( Convert.InvalidProfile e ) {
			prc.response.setErrorMessage( e.message, 400 );
		}
	}

	/**
	 * POST /cbstudio/api/sites/:site/convert with { profile, contentIDs: [] }: convert what is ready, each as a new
	 * version. Returns { saved: [ { contentID, slug } ], skipped: [ { contentID, slug, reason } ] }.
	 */
	function apply( event, rc, prc ) secured="STUDIO_CONVERT" {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		if ( !isArray( rc.contentIDs ?: "" ) ) {
			prc.response.setErrorMessage( "contentIDs must be an array", 400 );
			return;
		}
		try {
			prc.response.setData(
				variables.pageConverter.apply(
					site       = site,
					profile    = text( rc.profile ?: "" ),
					contentIDs = rc.contentIDs,
					author     = jwtAuth().getUser()
				)
			);
		} catch ( Convert.ProfileNotFound e ) {
			prc.response.setErrorMessage( e.message, 404 );
		} catch ( Convert.InvalidProfile e ) {
			prc.response.setErrorMessage( e.message, 400 );
		} catch ( Convert.Forbidden e ) {
			prc.response.setErrorMessage( e.message, 403 );
		}
	}

	/**
	 * POST /cbstudio/api/sites/:site/copy with { name, slug, domain, theme }: a new site as a copy of this one (it is
	 * only read). Returns SiteCopy.copy()'s result.
	 */
	function copy( event, rc, prc ) secured="STUDIO_CONVERT" {
		if ( !hasAnyPermission( "SITES_ADMIN" ) ) {
			prc.response.setErrorMessage( "Copying a site needs SITES_ADMIN", 403 );
			return;
		}
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		try {
			prc.response.setData(
				variables.siteCopy.copy(
					source = site,
					name   = text( rc.name ?: "" ),
					slug   = text( rc.slug ?: "" ),
					domain = text( rc.domain ?: "" ),
					theme  = text( rc.theme ?: "" )
				)
			);
		} catch ( SiteCopy.Invalid e ) {
			prc.response.setErrorMessage( e.message, 400 );
		}
	}

	private string function text( any value = "" ) {
		return isSimpleValue( arguments.value ) ? trim( toString( arguments.value ) ) : "";
	}

}
