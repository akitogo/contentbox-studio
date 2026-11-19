/**
 * Block types and block rendering
 */
component extends="BaseHandler" {
	property name="registry" inject="BlockRegistry@contentbox-studio";

	property name="renderer" inject="BlockRenderer@contentbox-studio";

	property name="contentRerender" inject="ContentRerender@contentbox-studio";
	this.allowedMethods = {
		"index"   : "GET",
		"render"  : "POST",
		"rerender": "POST"
	};

	/**
	 * GET /cbstudio/api/blocks?site=<siteID or slug>: the block types of the site's theme (default site without ?site)
	 */
	function index( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		prc.response.setData( variables.registry.publicDefinitions( variables.registry.forSite( site ) ) );
	}

	/**
	 * POST /cbstudio/api/blocks/render with JSON { site, blocks: [ { type, id, data } ], editable }
	 * Renders without saving (preview): normalized blocks, their HTML, the body and validation errors.
	 * editable: true for the editor canvas (text fields marked for editing in place).
	 */
	function render( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		if ( !isArray( rc.blocks ?: "" ) ) {
			prc.response.setErrorMessage( "blocks must be an array", 400 );
			return;
		}
		var editable = rc.editable ?: false;
		prc.response.setData(
			variables.renderer.renderBlocks(
				site     = site,
				blocks   = rc.blocks,
				editable = isBoolean( editable ) && editable
			)
		);
	}

	/**
	 * POST /cbstudio/api/blocks/rerender with JSON { site }: re-render all block content of the site with the current
	 * templates, saving new versions where the HTML changes. For administrators after theme updates (THEME_ADMIN).
	 */
	function rerender( event, rc, prc ) secured="THEME_ADMIN" {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		prc.response.setData( variables.contentRerender.rerenderSite( site, jwtAuth().getUser() ) );
	}

}