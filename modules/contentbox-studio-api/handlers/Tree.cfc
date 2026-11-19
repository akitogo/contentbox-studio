/**
 * The page tree of a site
 */
component extends="BaseHandler" {
	property name="siteTree" inject="SiteTree@contentbox-studio";

	property name="pageService" inject="pageService@contentbox";
	this.allowedMethods = { "index": "GET", "move": "POST", "create": "POST" };

	/**
	 * GET /cbstudio/api/sites/:site/tree: all pages of the site, flat, with parentID, order and status
	 */
	function index( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		prc.response.setData( variables.siteTree.getPages( site ) );
	}

	/**
	 * POST /cbstudio/api/pages/:contentID/move with JSON { parentID ("" for the root), index (0-based) }
	 * Needs STUDIO_SITE_TREE and PAGES_ADMIN or PAGES_EDITOR. Returns { slug, previousSlug }.
	 */
	function move( event, rc, prc ) secured="STUDIO_SITE_TREE" {
		if ( !hasAnyPermission( "PAGES_ADMIN,PAGES_EDITOR" ) ) {
			prc.response.setErrorMessage( "Moving pages needs PAGES_ADMIN or PAGES_EDITOR", 403 );
			return;
		}
		var page = variables.pageService.get( id = rc.contentID ?: "", returnNew = false );
		if ( isNull( page ) ) {
			prc.response.setErrorMessage( "Page not found", 404 );
			return;
		}
		var index = isNumeric( rc.index ?: "" ) ? rc.index : 0;
		try {
			prc.response.setData(
				variables.siteTree.movePage(
					page,
					toString( rc.parentID ?: "" ),
					index
				)
			);
		} catch (SiteTree.InvalidMove e) {
			prc.response.setErrorMessage( e.message, 409 );
		}
	}

	/**
	 * POST /cbstudio/api/sites/:site/pages with JSON { title, slug, parentID, templateID }: a new draft page.
	 * Needs PAGES_ADMIN or PAGES_EDITOR. Returns { contentID, slug }.
	 */
	function create( event, rc, prc ) {
		if ( !hasAnyPermission( "PAGES_ADMIN,PAGES_EDITOR" ) ) {
			prc.response.setErrorMessage( "Creating pages needs PAGES_ADMIN or PAGES_EDITOR", 403 );
			return;
		}
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		try {
			var page = variables.siteTree.createPage(
				site       = site,
				title      = toString( rc.title ?: "" ),
				slug       = toString( rc.slug ?: "" ),
				parentID   = toString( rc.parentID ?: "" ),
				templateID = toString( rc.templateID ?: "" ),
				author     = jwtAuth().getUser()
			);
			prc
				.response
				.setData(
					{
						"contentID": page.getContentID(),
						"slug"     : page.getSlug()
					}
				)
				.setStatusCode( 201 );
		} catch (SiteTree.InvalidPage e) {
			prc.response.setErrorMessage( e.message, 409 );
		}
	}

}