/**
 * Base for all Studio API handlers. RestHandler provides the JSON responses, including
 * onAuthenticationFailure (401) and onAuthorizationFailure (403) used by the module's firewall.
 */
component extends="coldbox.system.RestHandler" {
	property name="siteService" inject="siteService@contentbox";

	property name="contentService" inject="contentService@contentbox";

	/**
	 * A site by id or slug; the default site if empty
	 */
	private function findSite( any idOrSlug = "" ) {
		if ( !isSimpleValue( arguments.idOrSlug ) || !len( arguments.idOrSlug ) ) {
			return variables.siteService.getDefaultSite();
		}
		var site = variables.siteService.get( id = arguments.idOrSlug, returnNew = false );
		return isNull( site ) ? variables.siteService.findBySlug( arguments.idOrSlug ) : site;
	}

	/**
	 * A page, blog entry or content store item by id
	 */
	private function findContent( any contentID = "" ) {
		if ( !isSimpleValue( arguments.contentID ) || !len( arguments.contentID ) ) {
			return;
		}
		return variables.contentService.get( id = arguments.contentID, returnNew = false );
	}

	/**
	 * True if the current author has one of the permissions (Author.hasPermission() takes a single one)
	 */
	private boolean function hasAnyPermission( required string permissions ) {
		var author = jwtAuth().getUser();
		return listToArray( arguments.permissions ).some( ( permission ) => author.hasPermission( permission ) );
	}

}