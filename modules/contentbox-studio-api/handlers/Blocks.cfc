/**
 * Block types and block rendering
 */
component extends="BaseHandler" {
	property name="registry" inject="BlockRegistry@contentbox-studio";

	property name="renderer" inject="BlockRenderer@contentbox-studio";

	property name="siteService" inject="siteService@contentbox";
	this.allowedMethods = { "index": "GET", "render": "POST" };

	/**
	 * GET /cbstudio/api/blocks?site=<siteID or slug>: the block types of the site's theme (default site without ?site)
	 */
	function index( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			return prc.response.setErrorMessage( "Site not found", 404 );
		}
		prc.response.setData( variables.registry.publicDefinitions( variables.registry.forSite( site ) ) );
	}

	/**
	 * POST /cbstudio/api/blocks/render with JSON { site, blocks: [ { type, id, data } ] }
	 * Renders without saving (preview): normalized blocks, their HTML, the body and validation errors.
	 */
	function render( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			return prc.response.setErrorMessage( "Site not found", 404 );
		}
		if ( !isArray( rc.blocks ?: "" ) ) {
			return prc.response.setErrorMessage( "blocks must be an array", 400 );
		}
		prc.response.setData( variables.renderer.renderBlocks( site, rc.blocks ) );
	}

	/**
	 * By id or slug; the default site if empty
	 */
	private function findSite( any idOrSlug = "" ) {
		if ( !isSimpleValue( arguments.idOrSlug ) || !len( arguments.idOrSlug ) ) {
			return variables.siteService.getDefaultSite();
		}
		var site = variables.siteService.get( id = arguments.idOrSlug, returnNew = false );
		return isNull( site ) ? variables.siteService.findBySlug( arguments.idOrSlug ) : site;
	}

}