/**
 * Translation groups: pages or blog entries of a site that are the same content in different languages. Groups stay
 * within one site: each site has its own content.
 *
 * Stored as two ContentBox custom fields on each member, so no extra tables are needed and the data travels with
 * exports: cbstudio_language (e.g. "de", "en-GB") and cbstudio_translationGroup (a shared id). Each language occurs at
 * most once per group. The public site gets hreflang links (interceptors/Translations.cfc); themes can use
 * forContent( content ).members for a language switcher.
 */
component singleton {
	property name="contentService" inject="contentService@contentbox";

	property name="customFieldService" inject="customFieldService@contentbox";

	property name="cbHelper" inject="provider:CBHelper@contentbox";
	variables.GROUP_KEY = "cbstudio_translationGroup";
	variables.LANGUAGE_KEY = "cbstudio_language";
	variables.LANGUAGE_PATTERN = "^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$";

	/**
	 * @return { contentID, language, group, members: [ { contentID, title, slug, contentType, siteID, siteName,
	 * language, url, isCurrent } ] } (members include the content itself; empty without a group)
	 */
	struct function forContent( required content ) {
		var group = getField( arguments.content, variables.GROUP_KEY );
		var members = len( group ) ? loadGroup( group ) : [];
		var current = arguments.content.getContentID();
		return {
			"contentID": current,
			"language" : getField( arguments.content, variables.LANGUAGE_KEY ),
			"group"    : group,
			"members"  : members.map(
				( member ) => describe( member, member.getContentID() == current )
			)
		};
	}

	/**
	 * Language and group of every content item of a site that has one, by content id
	 *
	 * @return { contentID: { language, group } }
	 */
	struct function languagesForSite( required site ) {
		transaction {
			var rows = ormExecuteQuery(
				"select c.contentID, f.key, f.value from cbCustomField f join f.relatedContent c
				where c.site.siteID = :siteID and f.key in (:keys)",
				{
					"siteID": arguments.site.getSiteID(),
					"keys"  : [ variables.LANGUAGE_KEY, variables.GROUP_KEY ]
				}
			);
		}
		var result = {};
		for ( var row in rows ) {
			if ( !result.keyExists( row[ 1 ] ) ) {
				result[ row[ 1 ] ] = { "language": "", "group": "" };
			}
			result[ row[ 1 ] ][ row[ 2 ] == variables.LANGUAGE_KEY ? "language" : "group" ] = row[ 3 ];
		}
		return result;
	}

	/**
	 * @language Language code like "de" or "en-GB", "" to remove it
	 *
	 * @throws Translations.Invalid
	 */
	void function setLanguage( required content, required string language ) {
		var code = trim( arguments.language );
		if ( len( code ) && !reFind( variables.LANGUAGE_PATTERN, code ) ) {
			invalid( "[#code#] is not a language code like de, en or en-GB" );
		}
		var group = getField( arguments.content, variables.GROUP_KEY );
		if ( len( group ) && len( code ) ) {
			for ( var member in loadGroup( group ) ) {
				if (
					member.getContentID() != arguments.content.getContentID() &&
						getField( member, variables.LANGUAGE_KEY ) == code
				) {
					invalid(
						"#member.getTitle()# already is the #code# version in this group"
					);
				}
			}
		}
		setField(
			arguments.content,
			variables.LANGUAGE_KEY,
			code
		);
		variables.contentService.save( arguments.content );
	}

	/**
	 * Put two content items into the same translation group (merging their groups)
	 *
	 * @throws Translations.Invalid
	 */
	void function link( required content, required other ) {
		if ( arguments.content.getContentID() == arguments.other.getContentID() ) {
			invalid( "Content cannot be its own translation" );
		}
		for ( var item in [ arguments.content, arguments.other ] ) {
			if ( !listFindNoCase( "page,entry", item.getContentType() ) ) {
				invalid( "Only pages and blog entries can have translations" );
			}
		}
		if (
			arguments
					.content
					.getSite()
					.getSiteID() !=
				arguments
					.other
					.getSite()
					.getSiteID()
		) {
			invalid( "Translations must be on the same site" );
		}

		var group = getField( arguments.content, variables.GROUP_KEY );
		var otherGroup = getField( arguments.other, variables.GROUP_KEY );
		var members = len( group ) ? loadGroup( group ) : [ arguments.content ];
		var joining = len( otherGroup ) ? loadGroup( otherGroup ) : [ arguments.other ];
		if ( !len( group ) ) {
			group = len( otherGroup )
				? otherGroup
				: lCase(
					replace(
						createUUID(),
						"-",
						"",
						"all"
					)
				);
		}

		// Everyone in both groups; built explicitly because append()'s return value differs between engines
		var everyone = [];
		everyone.append( members, true );
		everyone.append( joining, true );

		// Each language once per group
		var languages = {};
		for ( var member in everyone ) {
			var language = getField( member, variables.LANGUAGE_KEY );
			if ( !len( language ) ) {
				continue;
			}
			if ( languages.keyExists( language ) && languages[ language ] != member.getContentID() ) {
				invalid( "The group would have two #language# versions" );
			}
			languages[ language ] = member.getContentID();
		}

		transaction {
			for ( var member in everyone ) {
				if ( getField( member, variables.GROUP_KEY ) != group ) {
					setField(
						member,
						variables.GROUP_KEY,
						group
					);
					variables.contentService.save( entity = member, transactional = false );
				}
			}
		}
	}

	/**
	 * Take content out of its group; a group left with one member is dissolved
	 */
	void function unlink( required content ) {
		var group = getField( arguments.content, variables.GROUP_KEY );
		if ( !len( group ) ) {
			return;
		}
		transaction {
			setField(
				arguments.content,
				variables.GROUP_KEY,
				""
			);
			variables.contentService.save( entity = arguments.content, transactional = false );
			var contentID = arguments.content.getContentID();
			var rest = loadGroup( group ).filter( ( member ) => member.getContentID() != contentID );
			if ( rest.len() == 1 ) {
				setField(
					rest[ 1 ],
					variables.GROUP_KEY,
					""
				);
				variables.contentService.save( entity = rest[ 1 ], transactional = false );
			}
		}
	}

	/********************************* PRIVATE *********************************/

	private array function loadGroup( required string group ) {
		transaction {
			var ids = ormExecuteQuery(
				"select c.contentID from cbCustomField f join f.relatedContent c where f.key = :key and f.value = :group",
				{ "key": variables.GROUP_KEY, "group": arguments.group }
			);
		}
		return ids.map( ( id ) => variables.contentService.get( id ) );
	}

	private struct function describe( required content, required boolean isCurrent ) {
		var site = arguments.content.getSite();
		return {
			"contentID"  : arguments.content.getContentID(),
			"title"      : arguments.content.getTitle(),
			"slug"       : arguments.content.getSlug(),
			"contentType": arguments.content.getContentType(),
			"siteID"     : site.getSiteID(),
			"siteName"   : site.getName(),
			"language"   : getField( arguments.content, variables.LANGUAGE_KEY ),
			"url"        : variables.cbHelper.linkContent( arguments.content ),
			"isCurrent"  : arguments.isCurrent
		};
	}

	private string function getField( required content, required string key ) {
		for ( var field in arguments.content.getCustomFields() ?: [] ) {
			if ( field.getKey() == arguments.key ) {
				return field.getValue();
			}
		}
		return "";
	}

	/**
	 * Set, change or (with "") remove a custom field; the caller saves the content
	 */
	private void function setField(
		required content,
		required string key,
		required string value
	) {
		for ( var field in arguments.content.getCustomFields() ?: [] ) {
			if ( field.getKey() == arguments.key ) {
				if ( len( arguments.value ) ) {
					field.setValue( arguments.value );
				} else {
					arguments.content.removeCustomField( field );
				}
				return;
			}
		}
		if ( len( arguments.value ) ) {
			var field = variables.customFieldService.new(
				properties = { "key": arguments.key, "value": arguments.value }
			);
			field.setRelatedContent( arguments.content );
			arguments.content.addCustomField( field );
		}
	}

	private void function invalid( required string message ) {
		throw( type = "Translations.Invalid", message = arguments.message );
	}

}