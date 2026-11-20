/**
 * The blog entries of a site for Studio's blog list, their categories, and new draft entries.
 *
 * Unlike /cbapi/v1/entries, the list includes drafts, scheduled and expired entries: it is for authors.
 */
component singleton {
	property name="entryService" inject="entryService@contentbox";

	property name="contentService" inject="contentService@contentbox";

	property name="templateService" inject="contentTemplateService@contentbox";

	property name="cbHelper" inject="provider:CBHelper@contentbox";

	property name="htmlHelper" inject="HTMLHelper@coldbox";

	property name="contentStatus" inject="ContentStatus@contentbox-studio";

	property name="contentEditor" inject="ContentEditor@contentbox-studio";

	property name="translations" inject="Translations@contentbox-studio";
	variables.MAX_ROWS = 500;

	/**
	 * Entries of a site, newest first (publish date, else creation date)
	 *
	 * @search   Part of the title or address, "" for all
	 * @status   draft, scheduled, published, expired or "" for all
	 * @category A category id, "none" for entries without a category, "" for all
	 * @offset   Rows to skip
	 * @max      Rows to return (1 to 500)
	 *
	 * @return { entries: [ { contentID, title, slug, status, isPublished, publishedDate, expireDate, author,
	 * categories: [ { categoryID, name, slug } ], hasBlocks, language, translationGroup, url } ], total, offset, max }
	 *
	 * @throws BlogEntries.InvalidFilter
	 */
	struct function list(
		required site,
		string search   = "",
		string status   = "",
		string category = "",
		numeric offset  = 0,
		numeric max     = 50
	) {
		var where = [ "e.site.siteID = :siteID" ];
		var params = { "siteID": arguments.site.getSiteID() };
		var term = trim( arguments.search );
		if ( len( term ) ) {
			where.append(
				"(lower(e.title) like :search or lower(e.slug) like :search)"
			);
			params[ "search" ] = "%#lCase( term )#%";
		}
		if ( len( arguments.status ) ) {
			if ( !variables.contentStatus.isStatus( arguments.status ) ) {
				invalidFilter(
					"Unknown status [#arguments.status#]: use draft, scheduled, published or expired"
				);
			}
			where.append( variables.contentStatus.hqlCondition( arguments.status, "e" ) );
			params.append( variables.contentStatus.hqlParams( arguments.status ) );
		}
		if ( arguments.category == "none" ) {
			where.append( "e.categories is empty" );
		} else if ( len( arguments.category ) ) {
			where.append(
				"e.contentID in (select ce.contentID from cbEntry ce join ce.categories cat where cat.categoryID = :categoryID)"
			);
			params[ "categoryID" ] = arguments.category;
		}
		// No max()/min(): the argument "max" would hide the function
		var skip = arguments.offset > 0 ? int( arguments.offset ) : 0;
		var rowCount = arguments.max < 1
			? 1
			: ( arguments.max > variables.MAX_ROWS ? variables.MAX_ROWS : int( arguments.max ) );
		var condition = where.toList( " and " );

		// In a transaction: with BoxLang ORM, statements are closed after an earlier commit in the same request
		transaction {
			var total = ormExecuteQuery(
				"select count(e.contentID) from cbEntry e where #condition#",
				params,
				true
			);
			var rows = ormExecuteQuery(
				"select e.contentID, e.title, e.slug, e.isPublished, e.publishedDate, e.expireDate, a.firstName, a.lastName
				from cbEntry e left join e.creator a
				where #condition#
				order by coalesce(e.publishedDate, e.createdDate) desc, e.title",
				params,
				false,
				{ "offset": skip, "maxResults": rowCount }
			);
		}

		var ids = rows.map( ( row ) => row[ 1 ] );
		var categories = categoriesOf( ids );
		var withBlocks = idsWithBlocks( ids );
		var languages = variables.translations.languagesForSite( arguments.site );
		// Same as CBHelper.linkEntry()
		var blogRoot = variables.cbHelper.linkBlog( arguments.site.getSiteID() ) & "/";
		var now = now();

		return {
			"entries": rows.map(
				( row ) => {
					var contentID = row[ 1 ];
					var info = languages[ contentID ] ?: {};
					return {
						"contentID": contentID,
						"title"    : row[ 2 ],
						"slug"     : row[ 3 ],
						"status"   : variables.contentStatus.of(
							row[ 4 ],
							row[ 5 ] ?: "",
							row[ 6 ] ?: "",
							now
						),
						"isPublished"     : row[ 4 ],
						"publishedDate"   : variables.contentStatus.isoDate( row[ 5 ] ?: "" ),
						"expireDate"      : variables.contentStatus.isoDate( row[ 6 ] ?: "" ),
						"author"          : trim( ( row[ 7 ] ?: "" ) & " " & ( row[ 8 ] ?: "" ) ),
						"categories"      : categories[ contentID ] ?: [],
						"hasBlocks"       : withBlocks.keyExists( contentID ),
						"language"        : info.language ?: "",
						"translationGroup": info.group ?: "",
						"url"             : blogRoot & row[ 3 ]
					};
				}
			),
			"total" : val( total ?: 0 ),
			"offset": skip,
			"max"   : rowCount
		};
	}

	/**
	 * Categories of a site, by name, with the number of entries in each
	 *
	 * @return [ { categoryID, name, slug, entries } ]
	 */
	array function categories( required site ) {
		transaction {
			var rows = ormExecuteQuery(
				"select c.categoryID, c.category, c.slug from cbCategory c where c.site.siteID = :siteID order by c.category",
				{ "siteID": arguments.site.getSiteID() }
			);
			var counts = ormExecuteQuery(
				"select cat.categoryID, count(e.contentID) from cbEntry e join e.categories cat
				where e.site.siteID = :siteID group by cat.categoryID",
				{ "siteID": arguments.site.getSiteID() }
			);
		}
		var entries = {};
		for ( var row in counts ) {
			entries[ row[ 1 ] ] = val( row[ 2 ] );
		}
		return rows.map(
			( row ) => {
				return {
					"categoryID": row[ 1 ],
					"name"      : row[ 2 ],
					"slug"      : row[ 3 ],
					"entries"   : entries[ row[ 1 ] ] ?: 0
				};
			}
		);
	}

	/**
	 * Create a draft entry, optionally starting from a content template for entries
	 *
	 * @slug       Address within the blog; from the title if empty
	 * @templateID Content template id or ""
	 * @author     Creator
	 *
	 * @return The new entry
	 *
	 * @throws BlogEntries.InvalidEntry
	 */
	function createEntry(
		required site,
		required string title,
		string slug       = "",
		string templateID = "",
		required author
	) {
		var entryTitle = trim( arguments.title );
		if ( !len( entryTitle ) ) {
			invalidEntry( "An entry needs a title" );
		}
		var entrySlug = variables.htmlHelper.slugify(
			len( trim( arguments.slug ) ) ? trim( arguments.slug ) : entryTitle
		);
		if ( !len( entrySlug ) ) {
			invalidEntry( "The address of the entry would be empty" );
		}
		if ( !variables.contentService.isSlugUnique( slug = entrySlug, siteID = arguments.site.getSiteID() ) ) {
			invalidEntry( "The address #entrySlug# is already used on this site" );
		}

		var body = "";
		if ( len( arguments.templateID ) ) {
			var template = variables.templateService.get( id = arguments.templateID, returnNew = false );
			if (
				isNull( template ) || template.getSite().getSiteID() != arguments.site.getSiteID() ||
					template.getContentType() != "Entry"
			) {
				invalidEntry( "The template does not exist for entries on this site" );
			}
			body = variables.contentEditor.templateBody( template );
		}

		var entry = variables.entryService.new(
			{
				"title"        : entryTitle,
				"slug"         : entrySlug,
				"isPublished"  : false,
				"publishedDate": now(),
				"site"         : arguments.site,
				"creator"      : arguments.author
			}
		);
		entry.addNewContentVersion(
			content   = body,
			changelog = "Created in ContentBox Studio",
			author    = arguments.author
		);
		return variables.entryService.save( entry );
	}

	/********************************* PRIVATE *********************************/

	/**
	 * Categories of the entries by content id, by name
	 */
	private struct function categoriesOf( required array ids ) {
		var result = {};
		if ( !arguments.ids.len() ) {
			return result;
		}
		transaction {
			var rows = ormExecuteQuery(
				"select e.contentID, cat.categoryID, cat.category, cat.slug from cbEntry e join e.categories cat
				where e.contentID in (:ids) order by cat.category",
				{ "ids": arguments.ids }
			);
		}
		for ( var row in rows ) {
			if ( !result.keyExists( row[ 1 ] ) ) {
				result[ row[ 1 ] ] = [];
			}
			result[ row[ 1 ] ].append(
				{
					"categoryID": row[ 2 ],
					"name"      : row[ 3 ],
					"slug"      : row[ 4 ]
				}
			);
		}
		return result;
	}

	/**
	 * Ids (as keys) of the entries whose active version has blocks
	 */
	private struct function idsWithBlocks( required array ids ) {
		var result = {};
		if ( !arguments.ids.len() ) {
			return result;
		}
		transaction {
			var rows = ormExecuteQuery(
				"select distinct c.contentID from cbContent c join c.contentVersions v
				where c.contentID in (:ids) and v.isActive = :active and v.content like :marker",
				{
					"ids"   : arguments.ids,
					"active": true,
					"marker": "%<!-- cb:block %"
				}
			);
		}
		for ( var id in rows ) {
			result[ id ] = true;
		}
		return result;
	}

	private void function invalidFilter( required string message ) {
		throw( type = "BlogEntries.InvalidFilter", message = arguments.message );
	}

	private void function invalidEntry( required string message ) {
		throw( type = "BlogEntries.InvalidEntry", message = arguments.message );
	}

}