/**
 * A new site as a copy of an existing one, for converting it without touching the original: ContentBox's own site
 * export and import (pages, blog entries, content store, categories, menus, settings, custom fields, versions), with
 * a new name, slug, domain and theme.
 *
 * The copy gets its own translation groups (new ids, so the original's groups stay as they are) and remembers where
 * it came from (site setting cbstudio_copiedFrom), which allows converting it to a new look. deleteCopy() removes a
 * copy again.
 */
component singleton {
	property name="siteService" inject="siteService@contentbox";

	property name="settingService" inject="settingService@contentbox";

	property name="themeService" inject="themeService@contentbox";

	property name="contentService" inject="contentService@contentbox";

	property name="contentVersionService" inject="contentVersionService@contentbox";

	property name="authorService" inject="authorService@contentbox";

	property name="menuService" inject="menuService@contentbox";

	property name="mediaService" inject="mediaService@contentbox";

	property name="populator" inject="wirebox:populator";

	property name="log" inject="logbox:logger:{this}";

	variables.COPY_SETTING = "cbstudio_copiedFrom";
	variables.GROUP_KEY = "cbstudio_translationGroup";
	variables.SLUG_PATTERN = "^[a-z0-9][a-z0-9-]*$";
	variables.DOMAIN_PATTERN = "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(:[0-9]{1,5})?$";

	/**
	 * Copy a site
	 *
	 * @source The site to copy; it is only read
	 * @name   Name of the copy
	 * @slug   Slug of the copy (lowercase letters, digits, dashes; unused)
	 * @domain Host name the copy answers to, e.g. new.example.com or new.localhost (not used by another site)
	 * @theme  Active theme of the copy
	 *
	 * @return { siteID, slug, name, domain, theme, pages, entries, contentStore, reachable, warnings: [] }
	 *
	 * @throws SiteCopy.Invalid
	 */
	struct function copy(
		required source,
		required string name,
		required string slug,
		required string domain,
		required string theme
	) {
		var siteName = trim( arguments.name );
		var siteSlug = lCase( trim( arguments.slug ) );
		var host = lCase( trim( arguments.domain ) );
		var themeName = trim( arguments.theme );
		if ( len( siteName ) < 2 || len( siteName ) > 255 ) {
			invalid( "The name needs 2 to 255 characters" );
		}
		if ( !reFind( variables.SLUG_PATTERN, siteSlug ) || len( siteSlug ) < 2 || len( siteSlug ) > 255 ) {
			invalid( "The slug may only have lowercase letters, digits and dashes (at least 2)" );
		}
		if ( !isNull( variables.siteService.findBySlug( siteSlug ) ) ) {
			invalid( "There is already a site with the slug '#siteSlug#'" );
		}
		if ( !reFind( variables.DOMAIN_PATTERN, host ) || len( host ) > 255 ) {
			invalid( "The domain must be a host name like new.example.com, without http:// or a path" );
		}
		for ( var site in variables.siteService.getAll() ) {
			if ( lCase( site.getDomain() ) == host ) {
				invalid( "The site '#site.getName()#' already uses the domain #host#" );
			}
		}
		if ( !variables.themeService.getThemes().keyExists( themeName ) ) {
			invalid( "There is no theme '#themeName#'" );
		}

		var memento = arguments.source.getMemento( profile = "export" );
		memento[ "name" ] = siteName;
		memento[ "slug" ] = siteSlug;
		memento[ "domain" ] = host;
		memento[ "domainRegex" ] = domainRegex( host );
		// The original's aliases must keep pointing at the original
		memento[ "domainAliases" ] = [];
		memento[ "activeTheme" ] = themeName;
		memento[ "isActive" ] = true;
		memento[ "settings" ] = memento.settings.filter( ( setting ) => setting.name != variables.COPY_SETTING );
		// ContentBox's import replaces the version collection of content it has already saved, which Hibernate refuses
		// on Adobe ColdFusion ("A collection with cascade=all-delete-orphan was no longer referenced"): the versions
		// are taken out here and added to the copied content afterwards
		var versions = {};
		for ( var key in [ "pages", "entries", "contentStore" ] ) {
			if ( isArray( memento[ key ] ?: "" ) ) {
				takeVersions( memento[ key ], versions );
			}
		}

		var importLog = createObject( "java", "java.lang.StringBuilder" ).init();
		transaction {
			variables.siteService.importSite(
				site      = variables.siteService.new(),
				memento   = memento,
				importLog = importLog,
				override  = false
			);
		}
		variables.settingService.flushSettingsCache();
		variables.log.info( "Site #arguments.source.getSlug()# copied to #siteSlug#", importLog.toString() );

		var copied = variables.siteService.findBySlug( siteSlug );
		transaction {
			addVersions( copied, versions );
			renewTranslationGroups( copied );
			var setting = variables.settingService.new();
			setting.setName( variables.COPY_SETTING );
			setting.setValue( arguments.source.getSiteID() );
			setting.setIsCore( false );
			setting.setSite( copied );
			entitySave( setting );
		}
		variables.settingService.flushSettingsCache();

		var warnings = [];
		var reachable = siteForUrl( "http://#host#/" ) == copied.getSiteID();
		if ( !reachable ) {
			warnings.append(
				"Another site's domain pattern also matches #host# and comes first, so the copy is not reachable there yet. Change that site's domain pattern in ContentBox's admin, or use another domain."
			);
		}
		return {
			"siteID"      : copied.getSiteID(),
			"slug"        : copied.getSlug(),
			"name"        : copied.getName(),
			"domain"      : copied.getDomain(),
			"theme"       : copied.getActiveTheme(),
			"pages"       : copied.getNumberOfPages(),
			"entries"     : copied.getNumberOfEntries(),
			"contentStore": copied.getNumberOfContentStore(),
			"reachable"   : reachable,
			"warnings"    : warnings
		};
	}

	/**
	 * Delete a copy made by copy(), with its content. ContentBox's own site delete removes the content with bulk
	 * statements on Adobe ColdFusion, which the foreign keys of versions and custom fields refuse; here content and
	 * menus are deleted one by one, so Hibernate's cascades apply. Hit counters (cbStats) are not part of those
	 * cascades and go first.
	 *
	 * @throws SiteCopy.Invalid for a site that is not a copy
	 */
	void function deleteCopy( required site ) {
		if ( !isCopy( arguments.site ) ) {
			invalid( "Only copies made by the conversion tool can be deleted here" );
		}
		var siteID = arguments.site.getSiteID();
		var media = variables.mediaService.getCoreMediaRoot( absolute = true ) & "/sites/" & arguments.site.getSlug();
		transaction {
			// Hit counters: ContentBox's content delete leaves them, and they refer to the content
			ormExecuteQuery(
				"delete from cbStats where relatedContent in (select c from cbContent c where c.site.siteID = :siteID)",
				{ "siteID": siteID }
			);
			// Top-level content only: deleting content deletes its children
			var roots = variables.contentService
				.newCriteria()
				.isEq( "site", arguments.site )
				.isNull( "parent" )
				.list();
			for ( var content in roots ) {
				variables.contentService.delete( content );
			}
			var menus = variables.menuService
				.newCriteria()
				.isEq( "site", arguments.site )
				.list();
			for ( var menu in menus ) {
				variables.menuService.delete( menu );
			}
		}
		ormClearSession();
		variables.siteService.delete( variables.siteService.get( siteID ) );
		// The empty media folder ContentBox made for the copy
		if ( directoryExists( media ) && !directoryList( media ).len() ) {
			directoryDelete( media );
		}
	}

	/**
	 * Whether a site was made by copy()
	 */
	boolean function isCopy( required site ) {
		return len( copiedFrom( arguments.site ) ) > 0;
	}

	/**
	 * siteID of the site a copy was made from, "" for other sites
	 */
	string function copiedFrom( required site ) {
		transaction {
			var rows = ormExecuteQuery(
				"select s.value from cbSetting s where s.name = :name and s.site.siteID = :siteID",
				{
					"name"  : variables.COPY_SETTING,
					"siteID": arguments.site.getSiteID()
				}
			);
		}
		return rows.len() ? toString( rows[ 1 ] ) : "";
	}

	/**
	 * Domain pattern for a host: the whole host, any port, nothing else (ContentBox matches it against the full URL)
	 */
	string function domainRegex( required string domain ) {
		var host = listFirst( arguments.domain, ":" );
		return "^https?://" & replace( host, ".", "\.", "all" ) & "(:[0-9]+)?(/|\?|$)";
	}

	/**
	 * siteID of the site ContentBox serves for a URL by its domain patterns ("" for the default site fallback)
	 */
	string function siteForUrl( required string url ) {
		for ( var site in variables.siteService.getAllFlat( isActive = true ) ) {
			if ( reFindNoCase( site[ "domainRegex" ], arguments.url ) ) {
				return site[ "siteID" ];
			}
			if ( isJSON( site[ "domainAliases" ] ?: "" ) ) {
				for ( var alias in deserializeJSON( site[ "domainAliases" ] ) ) {
					if ( isStruct( alias ) && alias.keyExists( "domainRegex" ) && reFindNoCase( alias.domainRegex, arguments.url ) ) {
						return site[ "siteID" ];
					}
				}
			}
		}
		return "";
	}

	/********************************* PRIVATE *********************************/

	/**
	 * Move the versions out of content mementos (children included) into versions[ slug ]
	 */
	private void function takeVersions( required array items, required struct versions ) {
		for ( var item in arguments.items ) {
			if ( !isStruct( item ) ) {
				continue;
			}
			if ( isArray( item.contentversions ?: "" ) ) {
				arguments.versions[ item.slug ] = item.contentversions;
				item[ "contentversions" ] = [];
			}
			if ( isArray( item.children ?: "" ) ) {
				takeVersions( item.children, arguments.versions );
			}
		}
	}

	/**
	 * Add the versions taken out of the mementos to the copied content, like ContentBox's import would
	 */
	private void function addVersions( required site, required struct versions ) {
		for ( var slug in arguments.versions ) {
			var content = variables.contentService.findWhere( { "slug": slug, "site": arguments.site } );
			if ( isNull( content ) ) {
				continue;
			}
			for ( var data in arguments.versions[ slug ] ) {
				var version = variables.populator.populateFromStruct(
					target               = variables.contentVersionService.new(),
					memento              = data,
					exclude              = "contentVersionID,author",
					composeRelationships = false
				);
				var editor = variables.authorService.findByEmail( data.author.email ?: "" );
				version.setAuthor( isNull( editor ) ? content.getCreator() : editor );
				version.setRelatedContent( content );
				content.addContentVersion( version );
				entitySave( version );
			}
		}
	}

	/**
	 * Give the copy's translation groups new ids: the import copies the custom fields, ids included
	 */
	private void function renewTranslationGroups( required site ) {
		var fields = ormExecuteQuery(
			"select f from cbCustomField f join f.relatedContent c where f.key = :key and c.site.siteID = :siteID",
			{
				"key"   : variables.GROUP_KEY,
				"siteID": arguments.site.getSiteID()
			}
		);
		var ids = {};
		for ( var field in fields ) {
			var old = field.getValue();
			if ( !ids.keyExists( old ) ) {
				ids[ old ] = lCase( replace( createUUID(), "-", "", "all" ) );
			}
			field.setValue( ids[ old ] );
			entitySave( field );
		}
	}

	private void function invalid( required string message ) {
		throw( type = "SiteCopy.Invalid", message = arguments.message );
	}

}
