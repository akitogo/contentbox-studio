/**
 * The blog of a site: entries for Studio's blog list (drafts included), categories, new entries
 */
component extends="BaseHandler" {
	property name="blogEntries" inject="BlogEntries@contentbox-studio";
	this.allowedMethods = {
		"index"     : "GET",
		"create"    : "POST",
		"categories": "GET"
	};

	/**
	 * GET /cbstudio/api/sites/:site/entries?search=&status=&category=&offset=0&max=50
	 * status: draft, scheduled, published, expired or empty; category: a category id, "none" or empty.
	 * Returns { entries, total, offset, max }, newest first.
	 */
	function index( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		try {
			prc.response.setData(
				variables.blogEntries.list(
					site     = site,
					search   = simple( rc.search ?: "" ),
					status   = simple( rc.status ?: "" ),
					category = simple( rc.category ?: "" ),
					offset   = val( simple( rc.offset ?: 0 ) ),
					max      = len( simple( rc.max ?: "" ) ) ? val( rc.max ) : 50
				)
			);
		} catch (BlogEntries.InvalidFilter e) {
			prc.response.setErrorMessage( e.message, 400 );
		}
	}

	/**
	 * GET /cbstudio/api/sites/:site/categories: [ { categoryID, name, slug, entries } ] by name
	 */
	function categories( event, rc, prc ) {
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		prc.response.setData( variables.blogEntries.categories( site ) );
	}

	/**
	 * POST /cbstudio/api/sites/:site/entries with JSON { title, slug, templateID }: a new draft entry.
	 * Needs ENTRIES_ADMIN or ENTRIES_EDITOR; 409 when the address is used or the site's blog is turned off.
	 * Returns { contentID, slug }.
	 */
	function create( event, rc, prc ) {
		if ( !hasAnyPermission( "ENTRIES_ADMIN,ENTRIES_EDITOR" ) ) {
			prc.response.setErrorMessage(
				"Creating blog entries needs ENTRIES_ADMIN or ENTRIES_EDITOR",
				403
			);
			return;
		}
		var site = findSite( rc.site ?: "" );
		if ( isNull( site ) ) {
			prc.response.setErrorMessage( "Site not found", 404 );
			return;
		}
		try {
			var entry = variables.blogEntries.createEntry(
				site       = site,
				title      = simple( rc.title ?: "" ),
				slug       = simple( rc.slug ?: "" ),
				templateID = simple( rc.templateID ?: "" ),
				author     = jwtAuth().getUser()
			);
			prc
				.response
				.setData(
					{
						"contentID": entry.getContentID(),
						"slug"     : entry.getSlug()
					}
				)
				.setStatusCode( 201 );
		} catch (BlogEntries.InvalidEntry e) {
			prc.response.setErrorMessage( e.message, 409 );
		} catch (BlogEntries.BlogDisabled e) {
			prc.response.setErrorMessage( e.message, 409 );
		}
	}

	/**
	 * A request value as a string ("" for arrays and structs)
	 */
	private string function simple( any value = "" ) {
		return isSimpleValue( arguments.value ) ? toString( arguments.value ) : "";
	}

}