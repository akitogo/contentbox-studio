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

	property name="contentService" inject="contentService@contentbox";

	property name="templateService" inject="contentTemplateService@contentbox";

	property name="htmlHelper" inject="HTMLHelper@coldbox";

	property name="contentStatus" inject="ContentStatus@contentbox-studio";

	property name="contentEditor" inject="ContentEditor@contentbox-studio";

	property name="contentEvents" inject="ContentEvents@contentbox-studio";

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
					"contentID": contentID,
					"parentID" : row[ 4 ] ?: "",
					"title"    : row[ 2 ],
					"slug"     : row[ 3 ],
					"order"    : isNumeric( row[ 5 ] ?: "" ) ? row[ 5 ] : 0,
					"status"   : variables.contentStatus.of(
						row[ 6 ],
						row[ 7 ] ?: "",
						row[ 8 ] ?: "",
						now
					),
					"isPublished"     : row[ 6 ],
					"publishedDate"   : variables.contentStatus.isoDate( row[ 7 ] ?: "" ),
					"expireDate"      : variables.contentStatus.isoDate( row[ 8 ] ?: "" ),
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
		var position = min( max( int( arguments.index ), 0 ), siblings.len() ) + 1;
		// insertAt() past the end fails on Adobe ColdFusion 2023
		if ( position > siblings.len() ) {
			siblings.append( page );
		} else {
			siblings.insertAt( position, page );
		}

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
		variables.contentEvents.saved( content = page, originalSlug = previousSlug );

		return { "slug": newSlug, "previousSlug": previousSlug };
	}

	/**
	 * Create a draft page, last among its siblings, optionally with the body of a content template (block preset)
	 *
	 * @site       The site
	 * @title      Page title
	 * @slug       Last slug segment, or "" to make one from the title
	 * @parentID   Parent page id or "" for the root
	 * @templateID Content template id or ""
	 * @author     Creator
	 *
	 * @return The new page
	 *
	 * @throws SiteTree.InvalidPage
	 */
	function createPage(
		required site,
		required string title,
		string slug       = "",
		string parentID   = "",
		string templateID = "",
		required author
	) {
		var pageTitle = trim( arguments.title );
		if ( !len( pageTitle ) ) {
			invalidPage( "A page needs a title" );
		}
		var segment = variables.htmlHelper.slugify(
			len( trim( arguments.slug ) ) ? listLast( trim( arguments.slug ), "/" ) : pageTitle
		);
		if ( !len( segment ) ) {
			invalidPage( "The address of the page would be empty" );
		}

		var parent = "";
		if ( len( arguments.parentID ) ) {
			parent = variables.pageService.get( id = arguments.parentID, returnNew = false );
			if ( isNull( parent ) || parent.getSite().getSiteID() != arguments.site.getSiteID() ) {
				invalidPage( "The parent page does not exist on this site" );
			}
		}
		var fullSlug = ( isObject( parent ) ? parent.getSlug() & "/" : "" ) & segment;
		if ( !variables.contentService.isSlugUnique( slug = fullSlug, siteID = arguments.site.getSiteID() ) ) {
			invalidPage( "There is already a page at #fullSlug#" );
		}

		var body = "";
		if ( len( arguments.templateID ) ) {
			var template = variables.templateService.get( id = arguments.templateID, returnNew = false );
			if ( isNull( template ) || template.getSite().getSiteID() != arguments.site.getSiteID() ) {
				invalidPage( "The template does not exist on this site" );
			}
			body = variables.contentEditor.templateBody( template );
		}

		// Last among the new siblings (orders need not be contiguous, e.g. after changes in the classic admin)
		var criteria = variables
			.pageService
			.newCriteria()
			.isEq( "site", arguments.site );
		if ( isObject( parent ) ) {
			criteria.isEq( "parent", parent );
		} else {
			criteria.isNull( "parent" );
		}
		var lastSibling = criteria.list( max = 1, sortOrder = "order desc" );
		var order = lastSibling.len() ? val( lastSibling[ 1 ].getOrder() ) + 1 : 1;

		var page = variables.pageService.new(
			{
				"title"        : pageTitle,
				"slug"         : fullSlug,
				"isPublished"  : false,
				"publishedDate": now(),
				"layout"       : "pages",
				"order"        : order,
				"site"         : arguments.site,
				"creator"      : arguments.author
			}
		);
		if ( isObject( parent ) ) {
			page.setParent( parent );
			page.setSlug( fullSlug );
		}
		page.addNewContentVersion(
			content   = body,
			changelog = "Created in ContentBox Studio",
			author    = arguments.author
		);
		variables.pageService.save( page );
		variables.contentEvents.saved( content = page, isNew = true );
		return page;
	}

	/********************************* PRIVATE *********************************/

	private void function invalidPage( required string message ) {
		throw( type = "SiteTree.InvalidPage", message = arguments.message );
	}

	private void function invalidMove( required string message ) {
		throw( type = "SiteTree.InvalidMove", message = arguments.message );
	}

}