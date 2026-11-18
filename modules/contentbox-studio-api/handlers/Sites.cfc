/**
 * Sites for Studio's site switcher. /cbapi/v1/sites needs SITES_ADMIN, which editors do not have.
 */
component extends="BaseHandler" {
	property name="siteService" inject="siteService@contentbox";
	this.allowedMethods = { "index": "GET", "contentStore": "GET" };

	/**
	 * GET /cbstudio/api/sites: active sites, sorted by name
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
						"siteRoot": site.getSiteRoot()
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
			return prc.response.setErrorMessage( "Site not found", 404 );
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

}