/**
 * Sites for Studio's site switcher. /cbapi/v1/sites needs SITES_ADMIN, which editors do not have.
 */
component extends="BaseHandler" {
	property name="contentEditor" inject="ContentEditor@contentbox-studio";

	property name="themeStyles" inject="ThemeStyles@contentbox-studio";
	this.allowedMethods = {
		"index"       : "GET",
		"contentStore": "GET",
		"templates"   : "GET",
		"styles"      : "GET"
	};

	/**
	 * GET /cbstudio/api/sites: active sites, sorted by name, with whether their blog is turned on and their home page
	 */
	function index( event, rc, prc ) {
		var sites = variables
			.siteService
			.getAll( sortOrder = "name" )
			.filter( ( site ) => site.getIsActive() )
			.map(
				( site ) => {
					return {
						"siteID"  : site.getSiteID(),
						"slug"    : site.getSlug(),
						"name"    : site.getName(),
						"siteRoot"     : site.getSiteRoot(),
						"isBlogEnabled": site.getIsBlogEnabled(),
						// Slug of the page ContentBox shows at the site root, or "cbBlog" for the blog
						"homepage"     : site.getHomepage() ?: ""
					};
				}
			);

		prc.response.setData( sites );
	}

	/**
	 * GET /cbstudio/api/sites/:site/contentstore: slug and title of the site's content store items (block picker)
	 */
	function contentStore( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		transaction {
			var rows = ormExecuteQuery(
				"select c.slug, c.title from cbContentStore c where c.site.siteID = :siteID order by c.title",
				{ "siteID": site.getSiteID() }
			);
		}
		prc.response.setData(
			rows.map(
				( row ) => {
					return { "slug": row[ 1 ], "title": row[ 2 ] };
				}
			)
		);
	}

	/**
	 * GET /cbstudio/api/sites/:site/templates?contentType=page: content templates (block presets)
	 */
	function templates( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		var contentType = listFindNoCase( "page,entry,contentStore", rc.contentType ?: "" ) ? rc.contentType : "page";
		prc.response.setData( variables.contentEditor.templates( site, contentType ) );
	}

	/**
	 * GET /cbstudio/api/sites/:site/styles: stylesheets of the site's theme for the editor canvas
	 */
	function styles( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		prc.response.setData( variables.themeStyles.stylesheets( site ) );
	}

}