/**
 * Re-renders all block content of a site with the current block templates, e.g. after a theme update.
 *
 * Pages, blog entries and content store items whose active version has blocks are rendered again; where the HTML
 * changes, a new version is saved (and so goes live) with a changelog note. Content with blocks changed outside
 * Studio is skipped and reported, see BlockRenderer.rerenderBody().
 */
component singleton {
	property name="renderer" inject="BlockRenderer@contentbox-studio";

	property name="contentService" inject="contentService@contentbox";

	property name="log" inject="logbox:logger:{this}";
	variables.CHANGELOG = "Re-rendered by ContentBox Studio with the current block templates";

	/**
	 * @site   The site whose content to re-render
	 * @author Author of the new versions
	 *
	 * @return { checked, updated: [ slug ], skipped: [ { slug, reason } ] }
	 */
	struct function rerenderSite( required site, required author ) {
		var result = { "checked": 0, "updated": [], "skipped": [] };

		// Ids first, then one transaction per item: after a committed transaction the ORM session's statements are
		// closed (BoxLang ORM, PostgreSQL), so nothing loaded before may be used afterwards
		for ( var contentID in findContentIDsWithBlocks( arguments.site ) ) {
			transaction {
				var content = variables.contentService.get( contentID );
				result.checked++;
				var rendered = variables.renderer.rerenderBody( arguments.site, content.getContent() );
				if ( len( rendered.skipped ) ) {
					result.skipped.append(
						{ "slug": content.getSlug(), "reason": rendered.skipped }
					);
				} else if ( rendered.changed > 0 ) {
					content.addNewContentVersion(
						content   = rendered.body,
						changelog = variables.CHANGELOG,
						author    = arguments.author
					);
					variables.contentService.save( entity = content, transactional = false );
					result.updated.append( content.getSlug() );
				}
			}
		}

		if ( result.updated.len() ) {
			variables.log.info(
				"ContentBox Studio re-rendered #result.updated.len()# items: #result.updated.toList()#"
			);
		}
		return result;
	}

	/**
	 * Ids of the pages, entries and content store items of the site whose active version contains a block marker
	 */
	array function findContentIDsWithBlocks( required site ) {
		transaction {
			var ids = ormExecuteQuery(
				"select distinct c.contentID from cbContent c join c.contentVersions v
				where c.site.siteID = :siteID and v.isActive = :active and v.content like :marker",
				{
					"siteID": arguments.site.getSiteID(),
					"active": true,
					"marker": "%<!-- cb:block %"
				}
			);
		}
		return ids;
	}

}