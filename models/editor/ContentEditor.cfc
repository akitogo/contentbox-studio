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
	variables.ADMIN_PERMISSIONS = {
		"page"        : "PAGES_ADMIN",
		"entry"       : "ENTRIES_ADMIN",
		"contentStore": "CONTENTSTORE_ADMIN"
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
	 * @blocks      [ { type, id, data } ] from the editor
	 * @changelog   Note for the new version
	 * @baseVersion Version number the editor started from (0 to skip the check)
	 *
	 * @return { saved: true, ...load() } or { saved: false, errors: [ { blockID, field, message } ] }
	 *
	 * @throws ContentEditor.Forbidden, ContentEditor.Conflict
	 */
	struct function save(
		required content,
		required array blocks,
		string changelog    = "",
		required author,
		numeric baseVersion = 0
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

		var result = variables.renderer.renderBlocks( arguments.content.getSite(), arguments.blocks );
		if ( result.errors.len() ) {
			return { "saved": false, "errors": result.errors };
		}

		transaction {
			arguments.content.addNewContentVersion(
				content   = result.body,
				changelog = len( trim( arguments.changelog ) )
					? trim( arguments.changelog )
					: "Edited in ContentBox Studio",
				author    = arguments.author
			);
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
					var definition = template.getDefinition();
					var body = isStruct( definition ) && isStruct( definition.content ?: "" )
						? toString( definition.content.value ?: "" )
						: "";
					return {
						"templateID" : template.getTemplateID(),
						"name"       : template.getName(),
						"description": template.getDescription() ?: "",
						"hasBlocks"  : variables.format.hasBlocks( body )
					};
				}
			);
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
		return {
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
			"url"        : listFindNoCase( "page,entry", type ) ? variables.cbHelper.linkContent( item ) : ""
		};
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