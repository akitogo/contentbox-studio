/**
 * Loading and saving the blocks of a page, blog entry or content store item.
 *
 * Saving renders the blocks on the server and stores the body as a new ContentBox version, so history, diff and
 * rollback in the classic admin keep working. Rules:
 *
 * - editing needs the content type's ContentBox permission (PAGES_ADMIN/EDITOR, ENTRIES_..., CONTENTSTORE_...)
 * - HTML blocks may only be added or changed with STUDIO_HTML_BLOCKS; without it they can stay, move or be removed
 * - a save based on an older version than the active one is refused (someone else saved in between)
 */
component singleton {
	property name="format" inject="BlockFormat@contentbox-studio";

	property name="renderer" inject="BlockRenderer@contentbox-studio";

	property name="contentService" inject="contentService@contentbox";

	property name="cbHelper" inject="provider:CBHelper@contentbox";

	property name="templateService" inject="contentTemplateService@contentbox";

	property name="translations" inject="Translations@contentbox-studio";

	property name="contentStatus" inject="ContentStatus@contentbox-studio";

	property name="entrySettings" inject="EntrySettings@contentbox-studio";
	variables.ADMIN_PERMISSIONS = {
		"page"        : "PAGES_ADMIN",
		"entry"       : "ENTRIES_ADMIN",
		"contentStore": "CONTENTSTORE_ADMIN"
	};

	// Column lengths of ContentBox's SEO fields
	variables.SEO_LENGTHS = {
		"title"      : 255,
		"description": 160,
		"keywords"   : 160
	};

	variables.EDIT_PERMISSIONS = {
		"page"        : "PAGES_ADMIN,PAGES_EDITOR",
		"entry"       : "ENTRIES_ADMIN,ENTRIES_EDITOR",
		"contentStore": "CONTENTSTORE_ADMIN,CONTENTSTORE_EDITOR"
	};

	boolean function canEdit( required content, required author ) {
		var permissions = variables.EDIT_PERMISSIONS[ arguments.content.getContentType() ] ?: "";
		var who = arguments.author;
		return listToArray( permissions ).some( ( permission ) => who.hasPermission( permission ) );
	}

	/**
	 * @return { content: details, blocks: parsed blocks, canEdit, canEditHtml }
	 */
	struct function load( required content, required author ) {
		return {
			"content"    : describe( arguments.content ),
			"blocks"     : variables.format.parse( arguments.content.getContent() ),
			"canEdit"    : canEdit( arguments.content, arguments.author ),
			"canEditHtml": arguments.author.hasPermission( "STUDIO_HTML_BLOCKS" )
		};
	}

	/**
	 * Saves the blocks as a new version (none if the body stays the same, e.g. only the SEO fields changed)
	 *
	 * @blocks      [ { type, id, data } ] from the editor
	 * @changelog   Note for the new version
	 * @baseVersion Version number the editor started from (0 to skip the check)
	 * @seo         { title, description, keywords } for ContentBox's HTML title, meta description and keywords; not
	 * versioned by ContentBox. Left unchanged if not given (like language and entry).
	 * @language    Language code of a page or entry ("" for none); needs STUDIO_SITE_TREE, like translations
	 * @entry       Settings of a blog entry, see EntrySettings.prepare()
	 *
	 * @return { saved: true, ...load() } or { saved: false, errors: [ { blockID, field, message } ] }
	 *
	 * @throws ContentEditor.Forbidden, ContentEditor.Conflict, ContentEditor.Invalid
	 */
	struct function save(
		required content,
		required array blocks,
		string changelog    = "",
		required author,
		numeric baseVersion = 0,
		struct seo,
		string language,
		struct entry
	) {
		if ( !canEdit( arguments.content, arguments.author ) ) {
			throw(
				type    = "ContentEditor.Forbidden",
				message = "You may not edit this content"
			);
		}
		var current = activeVersion( arguments.content );
		if ( arguments.baseVersion > 0 && arguments.baseVersion != current ) {
			throw(
				type    = "ContentEditor.Conflict",
				message = "This content was saved by someone else in the meantime (version #current#). Reload it to see the changes."
			);
		}
		if ( !arguments.author.hasPermission( "STUDIO_HTML_BLOCKS" ) ) {
			checkHtmlBlocks( arguments.content, arguments.blocks );
		}
		// Everything is checked before anything changes
		var type = normalizedType( arguments.content );
		var seoUpdate = isNull( arguments.seo ) ? {} : seoValues( arguments.seo );
		if ( !isNull( arguments.language ) ) {
			if ( !listFindNoCase( "page,entry", type ) ) {
				invalid( "Only pages and blog entries have a language" );
			}
			if ( !arguments.author.hasPermission( "STUDIO_SITE_TREE" ) ) {
				throw(
					type    = "ContentEditor.Forbidden",
					message = "Setting the language needs the STUDIO_SITE_TREE permission"
				);
			}
			try {
				variables.translations.checkLanguage( arguments.content, arguments.language );
			} catch (Translations.Invalid e) {
				invalid( e.message );
			}
		}
		var entryUpdate = {};
		if ( !isNull( arguments.entry ) ) {
			if ( type != "entry" ) {
				invalid( "Only blog entries have entry settings" );
			}
			entryUpdate = variables.entrySettings.prepare( arguments.content, arguments.entry );
		}

		var result = variables.renderer.renderBlocks( arguments.content.getSite(), arguments.blocks );
		if ( result.errors.len() ) {
			return { "saved": false, "errors": result.errors };
		}

		transaction {
			if ( compare( result.body, arguments.content.getContent() ) != 0 ) {
				arguments.content.addNewContentVersion(
					content   = result.body,
					changelog = len( trim( arguments.changelog ) )
						? trim( arguments.changelog )
						: "Edited in ContentBox Studio",
					author    = arguments.author
				);
			}
			if ( !seoUpdate.isEmpty() ) {
				arguments.content.setHTMLTitle( seoUpdate.title );
				arguments.content.setHTMLDescription( seoUpdate.description );
				arguments.content.setHTMLKeywords( seoUpdate.keywords );
			}
			if ( !entryUpdate.isEmpty() ) {
				variables.entrySettings.apply( arguments.content, entryUpdate );
			}
			if ( !isNull( arguments.language ) ) {
				variables.translations.applyLanguage( arguments.content, arguments.language );
			}
			variables.contentService.save( entity = arguments.content, transactional = false );
		}

		var loaded = load( arguments.content, arguments.author );
		loaded[ "saved" ] = true;
		return loaded;
	}

	/**
	 * The latest versions, newest first
	 *
	 * @return [ { versionID, version, isActive, createdDate, changelog, author } ]
	 */
	array function versions( required content, numeric max = 50 ) {
		var list = [];
		for ( var version in arguments.content.getContentVersions() ?: [] ) {
			list.append(
				{
					"versionID"  : version.getContentVersionID(),
					"version"    : version.getVersion(),
					"isActive"   : version.getIsActive(),
					"createdDate": isDate( version.getCreatedDate() ?: "" )
						? dateTimeFormat( version.getCreatedDate(), "yyyy-mm-dd'T'HH:nn:ss" )
						: "",
					"changelog": version.getChangelog() ?: "",
					"author"   : version.hasAuthor() ? version.getAuthor().getFullName() : ""
				}
			);
		}
		list.sort( ( a, b ) => b.version - a.version );
		return list.len() > arguments.max ? list.slice( 1, arguments.max ) : list;
	}

	/**
	 * The blocks of one version
	 *
	 * @return { version, isActive, blocks } or null if the content has no such version
	 */
	function version( required content, required string versionID ) {
		for ( var version in arguments.content.getContentVersions() ?: [] ) {
			if ( version.getContentVersionID() == arguments.versionID ) {
				return {
					"version" : version.getVersion(),
					"isActive": version.getIsActive(),
					"blocks"  : variables.format.parse( version.getContent() )
				};
			}
		}
	}

	/**
	 * Publish or unpublish. Publishing a page whose publish date is in the future keeps it scheduled.
	 *
	 * @throws ContentEditor.Forbidden
	 */
	struct function setPublished(
		required content,
		required boolean isPublished,
		required author
	) {
		if ( !canEdit( arguments.content, arguments.author ) ) {
			throw(
				type    = "ContentEditor.Forbidden",
				message = "You may not edit this content"
			);
		}
		arguments.content.setIsPublished( arguments.isPublished );
		if ( arguments.isPublished && !isDate( arguments.content.getPublishedDate() ?: "" ) ) {
			arguments.content.setPublishedDate( now() );
		}
		variables.contentService.save( arguments.content );
		return load( arguments.content, arguments.author );
	}

	/**
	 * Content templates of a site for a content type: ContentBox's templates, used by Studio as block presets
	 *
	 * @return [ { templateID, name, description, hasBlocks } ]
	 */
	array function templates( required site, string contentType = "page" ) {
		var type = uCase( left( arguments.contentType, 1 ) ) & mid(
			arguments.contentType,
			2,
			len( arguments.contentType )
		);
		return variables
			.templateService
			.newCriteria()
			.isEq( "site", arguments.site )
			.isEq( "contentType", type )
			.list( sortOrder = "name asc" )
			.map(
				( template ) => {
					return {
						"templateID" : template.getTemplateID(),
						"name"       : template.getName(),
						"description": template.getDescription() ?: "",
						"hasBlocks"  : variables.format.hasBlocks( templateBody( template ) )
					};
				}
			);
	}

	/**
	 * The body a content template starts new content with ("" if it has none)
	 */
	string function templateBody( required template ) {
		var definition = arguments.template.getDefinition();
		return isStruct( definition ) && isStruct( definition.content ?: "" )
			? toString( definition.content.value ?: "" )
			: "";
	}

	/**
	 * Store the saved body of the content as a ContentBox content template (block preset for new content)
	 *
	 * @throws ContentEditor.Forbidden, ContentEditor.Invalid
	 */
	struct function saveAsTemplate(
		required content,
		required string name,
		string description = "",
		required author
	) {
		var permission = variables.ADMIN_PERMISSIONS[ normalizedType( arguments.content ) ] ?: "";
		if ( !len( permission ) || !arguments.author.hasPermission( permission ) ) {
			throw(
				type    = "ContentEditor.Forbidden",
				message = "Saving templates needs the #permission# permission"
			);
		}
		if ( !len( trim( arguments.name ) ) ) {
			throw(
				type    = "ContentEditor.Invalid",
				message = "A template needs a name"
			);
		}
		var template = variables.templateService.new(
			{
				"name"       : trim( arguments.name ),
				"description": trim( arguments.description ),
				"contentType": arguments.content.getContentType(),
				"site"       : arguments.content.getSite(),
				"creator"    : arguments.author,
				"isGlobal"   : false
			}
		);
		template.setDefinition(
			serializeJSON(
				{ "content": { "value": arguments.content.getContent() } }
			)
		);
		variables.templateService.save( template );
		return {
			"templateID": template.getTemplateID(),
			"name"      : template.getName()
		};
	}

	/********************************* PRIVATE *********************************/

	private void function invalid( required string message ) {
		throw( type = "ContentEditor.Invalid", message = arguments.message );
	}

	/**
	 * Trimmed SEO values from the editor, missing ones as ""
	 *
	 * @throws ContentEditor.Invalid if one is longer than ContentBox stores
	 */
	private struct function seoValues( required struct seo ) {
		var values = {};
		for ( var key in variables.SEO_LENGTHS ) {
			var value = arguments.seo[ key ] ?: "";
			values[ key ] = isSimpleValue( value ) ? trim( value ) : "";
			if ( len( values[ key ] ) > variables.SEO_LENGTHS[ key ] ) {
				throw(
					type    = "ContentEditor.Invalid",
					message = "The SEO #key# may have at most #variables.SEO_LENGTHS[ key ]# characters"
				);
			}
		}
		return values;
	}

	private struct function describe( required content ) {
		var item = arguments.content;
		// ContentBox stores "Page", "Entry", "ContentStore"; the API uses page, entry, contentStore
		var type = item.getContentType();
		type = lCase( left( type, 1 ) ) & mid(
			type,
			2,
			len( type )
		);
		var parent = item.hasParent() ? item.getParent() : "";
		var details = {
			"contentID"  : item.getContentID(),
			"contentType": type,
			"title"      : item.getTitle(),
			"slug"       : item.getSlug(),
			"siteID"     : item.getSite().getSiteID(),
			"siteSlug"   : item.getSite().getSlug(),
			"layout"     : type == "page" ? item.getLayout() : "",
			"parentID"   : isObject( parent ) ? parent.getContentID() : "",
			"isPublished": item.getIsPublished(),
			"version"    : activeVersion( item ),
			"status"     : variables.contentStatus.of(
				item.getIsPublished(),
				item.getPublishedDate() ?: "",
				item.getExpireDate() ?: ""
			),
			"publishedDate": variables.contentStatus.isoDate( item.getPublishedDate() ?: "" ),
			"expireDate"   : variables.contentStatus.isoDate( item.getExpireDate() ?: "" ),
			"language"     : listFindNoCase( "page,entry", type ) ? variables.translations.languageOf( item ) : "",
			"seo"          : {
				"title"      : item.getHTMLTitle() ?: "",
				"description": item.getHTMLDescription() ?: "",
				"keywords"   : item.getHTMLKeywords() ?: ""
			},
			"url": listFindNoCase( "page,entry", type ) ? variables.cbHelper.linkContent( item ) : ""
		};
		if ( type == "entry" ) {
			details[ "entry" ] = variables.entrySettings.describe( item );
		}
		return details;
	}

	/**
	 * page, entry or contentStore (ContentBox stores "Page", "Entry", "ContentStore")
	 */
	private string function normalizedType( required content ) {
		var type = arguments.content.getContentType();
		return lCase( left( type, 1 ) ) & mid(
			type,
			2,
			len( type )
		);
	}

	private numeric function activeVersion( required content ) {
		for ( var version in arguments.content.getContentVersions() ?: [] ) {
			if ( version.getIsActive() ) {
				return version.getVersion();
			}
		}
		return 0;
	}

	/**
	 * Without STUDIO_HTML_BLOCKS every HTML block must exist unchanged (same id, same HTML) in the stored body
	 */
	private void function checkHtmlBlocks( required content, required array blocks ) {
		var existing = {};
		for ( var block in variables.format.parse( arguments.content.getContent() ) ) {
			if ( block.type == "html" ) {
				existing[ block.id ] = block.html;
			}
		}
		for ( var block in arguments.blocks ) {
			if ( !isStruct( block ) || ( block.type ?: "" ) != "html" ) {
				continue;
			}
			var id = isSimpleValue( block.id ?: "" ) ? toString( block.id ?: "" ) : "";
			var html = isStruct( block.data ?: "" ) && isSimpleValue( block.data.html ?: "" )
				? toString( block.data.html ?: "" )
				: "";
			if ( !existing.keyExists( id ) || compare( existing[ id ], html ) != 0 ) {
				throw(
					type    = "ContentEditor.Forbidden",
					message = "Adding or changing HTML blocks needs the STUDIO_HTML_BLOCKS permission"
				);
			}
		}
	}

}