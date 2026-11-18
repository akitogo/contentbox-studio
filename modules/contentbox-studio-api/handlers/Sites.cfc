/**
 * Sites for Studio's site switcher. /cbapi/v1/sites needs SITES_ADMIN, which editors do not have.
 */
component extends="BaseHandler" {
	property name="siteService" inject="siteService@contentbox";
	this.allowedMethods = { "index": "GET" };

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

}