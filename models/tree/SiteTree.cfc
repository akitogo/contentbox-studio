/**
 * The page tree of a site: listing with status, moving and reordering.
 *
 * ContentBox keeps the hierarchy in the slug ("parent/child"). Moving a page sets its parent and slug and lets
 * PageService.save() update the slugs of all descendants and add relocations (301 redirects) for the old URLs.
 */
component singleton {
	property name="pageService" inject="pageService@contentbox";

	property name="cbHelper" inject="provider:CBHelper@contentbox";

	property name="contentRerender" inject="ContentRerender@contentbox-studio";

	property name="translations" inject="Translations@contentbox-studio";

	/**
	 * All pages of a site as a flat list, sorted by parent order (order, then title)
	 *
	 * @return [ { contentID, parentID, title, slug, order, status, isPublished, publishedDate, expireDate, showInMenu,
	 * hasBlocks, language, translationGroup, url } ]
	 */
	array function getPages( required site ) {
		// In a transaction: with BoxLang ORM, statements are closed after an earlier commit in the same request
		transaction {
			var rows = ormExecuteQuery(
				"select p.contentID, p.title, p.slug, par.contentID, p.order, p.isPublished, p.publishedDate, p.expireDate, p.showInMenu
				from cbPage p left join p.parent par
				where p.site.siteID = :siteID",
				{ "siteID": arguments.site.getSiteID() }
			);
		}
		var withBlocks = {};
		for ( var id in variables.contentRerender.findContentIDsWithBlocks( arguments.site ) ) {
			withBlocks[ id ] = true;
		}
		var languages = variables.translations.languagesForSite( arguments.site );
		// Same as CBHelper.linkPage(): site root, "/" (CBHelper.sep() is private), slug
		var root = variables.cbHelper.siteRoot( arguments.site.getSiteID() ) & "/";
		var now = now();

		var pages = rows.map(
			( row ) => {
				var contentID = row[ 1 ];
				var info = languages[ contentID ] ?: {};
				return {
					"contentID"       : contentID,
					"parentID"        : row[ 4 ] ?: "",
					"title"           : row[ 2 ],
					"slug"            : row[ 3 ],
					"order"           : isNumeric( row[ 5 ] ?: "" ) ? row[ 5 ] : 0,
					"status"          : status(
						row[ 6 ],
						row[ 7 ] ?: "",
						row[ 8 ] ?: "",
						now
					),
					"isPublished"     : row[ 6 ],
					"publishedDate"   : isoDate( row[ 7 ] ?: "" ),
					"expireDate"      : isoDate( row[ 8 ] ?: "" ),
					"showInMenu"      : row[ 9 ],
					"hasBlocks"       : withBlocks.keyExists( contentID ),
					"language"        : info.language ?: "",
					"translationGroup": info.group ?: "",
					"url"             : root & row[ 3 ]
				};
			}
		);
		pages.sort(
			( a, b ) => a.order == b.order ? compareNoCase( a.title, b.title ) : a.order - b.order
		);
		return pages;
	}

	/**
	 * Move a page under a new parent (or to the root) at a position among its new siblings
	 *
	 * @movingPage The page to move
	 * @parentID Content id of the new parent, "" for the root
	 * @index    0-based position among the new siblings
	 *
	 * @return { slug, previousSlug }
	 *
	 * @throws SiteTree.InvalidMove
	 */
	struct function movePage(
		required movingPage,
		string parentID = "",
		numeric index   = 0
	) {
		var page = arguments.movingPage;
		var site = page.getSite();
		var parent = "";
		if ( len( arguments.parentID ) ) {
			parent = variables.pageService.get( id = arguments.parentID, returnNew = false );
			if ( isNull( parent ) || parent.getSite().getSiteID() != site.getSiteID() ) {
				invalidMove( "The new parent page does not exist on this site" );
			}
			// No page under itself or one of its descendants
			var ancestor = parent;
			while ( !isNull( ancestor ) ) {
				if ( ancestor.getContentID() == page.getContentID() ) {
					invalidMove(
						"A page cannot be moved under itself or one of its subpages"
					);
				}
				ancestor = ancestor.getParent();
			}
		}

		var previousSlug = page.getSlug();
		var newSlug = ( isObject( parent ) ? parent.getSlug() & "/" : "" ) & listLast( previousSlug, "/" );
		if ( compare( newSlug, previousSlug ) != 0 ) {
			var existing = variables.pageService.findWhere( { "slug": newSlug, "site": site } );
			if ( !isNull( existing ) ) {
				invalidMove( "There is already a page at #newSlug#" );
			}
		}

		// New siblings in their current order, with the page inserted at its position
		var criteria = variables
			.pageService
			.newCriteria()
			.isEq( "site", site )
			.ne( "contentID", page.getContentID() );
		if ( isObject( parent ) ) {
			criteria.isEq( "parent", parent );
		} else {
			criteria.isNull( "parent" );
		}
		var siblings = [];
		for ( var sibling in criteria.list( sortOrder = "order asc, title asc" ) ) {
			siblings.append( sibling );
		}
		siblings.insertAt(
			min( max( int( arguments.index ), 0 ), siblings.len() ) + 1,
			page
		);

		if ( isObject( parent ) ) {
			page.setParent( parent );
		} else {
			page.setParent( javacast( "null", "" ) );
		}
		// Set explicitly: setParent() only adds the parent slug if the slug does not already contain it
		page.setSlug( newSlug );
		for ( var i = 1; i <= siblings.len(); i++ ) {
			siblings[ i ].setOrder( i );
		}
		// One transaction: saves the page, updates descendants' slugs and adds relocations when the slug changed;
		// the commit also flushes the new order of the siblings, which are loaded in this ORM session
		variables.pageService.save(
			page         = page,
			originalSlug = compare( newSlug, previousSlug ) != 0 ? previousSlug : ""
		);

		return { "slug": newSlug, "previousSlug": previousSlug };
	}

	/********************************* PRIVATE *********************************/

	private string function status(
		required boolean isPublished,
		publishedDate,
		expireDate,
		required date now
	) {
		if ( !arguments.isPublished ) {
			return "draft";
		}
		if ( isDate( arguments.expireDate ) && arguments.expireDate <= arguments.now ) {
			return "expired";
		}
		if ( isDate( arguments.publishedDate ) && arguments.publishedDate > arguments.now ) {
			return "scheduled";
		}
		return "published";
	}

	private string function isoDate( any value ) {
		return isDate( arguments.value ?: "" ) ? dateTimeFormat( arguments.value, "yyyy-mm-dd'T'HH:nn:ss" ) : "";
	}

	private void function invalidMove( required string message ) {
		throw( type = "SiteTree.InvalidMove", message = arguments.message );
	}

}