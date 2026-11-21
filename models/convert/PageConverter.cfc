/**
 * Converts the HTML of pages, blog entries and content store items into blocks, with the rules of a conversion
 * profile (Profiles.cfc).
 *
 * Every top-level part of a body (an element, or a widget call between elements) is matched against the rules in
 * order; a match becomes a block with the data read from the HTML (FieldReader.cfc), anything else stays HTML
 * (neighbouring HTML parts become one HTML block). {{{ContentStore slug="..."}}} becomes a content store block.
 * Each block is rendered and compared with its part:
 *
 * - markup: the same canonical DOM (the blocks reproduce the old HTML, e.g. a theme made from the old one)
 * - content: every text, link and image of the part is in the rendered block (a new look)
 *
 * A body is ready when every part passes and at least one became a block; only ready content is converted, as a new
 * version (undo: restore the previous one). Content with blocks is skipped. A new look (content) can only be applied
 * on a copy of a site (SiteCopy.cfc), so the original stays as it is.
 */
component singleton {
	property name="registry" inject="BlockRegistry@contentbox-studio";

	property name="renderer" inject="BlockRenderer@contentbox-studio";

	property name="format" inject="BlockFormat@contentbox-studio";

	property name="editor" inject="ContentEditor@contentbox-studio";

	property name="html" inject="HtmlTree@contentbox-studio";

	property name="reader" inject="FieldReader@contentbox-studio";

	property name="profiles" inject="Profiles@contentbox-studio";

	property name="siteCopy" inject="SiteCopy@contentbox-studio";

	property name="contentService" inject="contentService@contentbox";

	variables.CHANGELOG = "Converted to Studio blocks";
	variables.CONTENT_TYPES = "Page,Entry,ContentStore";
	variables.STORE_CALL = "^\{\{\{\s*ContentStore\s+slug=""([A-Za-z0-9_/-]+)""\s*\}\}\}$";

	/**
	 * Dry run over a site's content
	 *
	 * @only A content ID: only this item, with the HTML of each part (the source and what it renders)
	 *
	 * @return { profile: { name, label, theme, compare }, canApply, problems: [], items: [ item ], totals: { items,
	 * ready, sections, converted, same } } (see convert() for an item; without only, parts have no HTML)
	 */
	struct function report( required site, required string profile, string only = "" ) {
		var prepared = prepare( arguments.site, arguments.profile );
		var result = {
			"profile"  : summary( prepared.profile ),
			"canApply" : prepared.canApply,
			"problems" : prepared.problems,
			"items"    : [],
			"totals"   : {
				"items"    : 0,
				"ready"    : 0,
				"sections" : 0,
				"converted": 0,
				"same"     : 0
			}
		};
		if ( prepared.problems.len() ) {
			return result;
		}
		var readers = {};
		for ( var content in contents( arguments.site ) ) {
			if ( len( arguments.only ) && content.getContentID() != arguments.only ) {
				continue;
			}
			var item = convert( content, prepared.profile, prepared.types, readers );
			if ( !len( arguments.only ) ) {
				for ( var section in item.sections ) {
					section.delete( "source" );
					section.delete( "rendered" );
					section.delete( "data" );
				}
			}
			result.items.append( item );
			result.totals.items++;
			result.totals.ready += item.ready ? 1 : 0;
			result.totals.sections += item.sections.len();
			result.totals.converted += item.sections.filter( ( section ) => section.type != "html" ).len();
			result.totals.same += item.sections.filter( ( section ) => section.same ).len();
		}
		return result;
	}

	/**
	 * Convert content of the site that is ready, each as a new version
	 *
	 * @return { saved: [ { contentID, slug } ], skipped: [ { contentID, slug, reason } ] }
	 *
	 * @throws Convert.InvalidProfile, Convert.Forbidden
	 */
	struct function apply(
		required site,
		required string profile,
		required array contentIDs,
		required author
	) {
		var prepared = prepare( arguments.site, arguments.profile );
		if ( prepared.problems.len() ) {
			throw( type = "Convert.InvalidProfile", message = prepared.problems.toList( "; " ) );
		}
		if ( !prepared.canApply ) {
			throw(
				type    = "Convert.Forbidden",
				message = "A new look (comparison ""content"") can only be applied to a copy of a site, so the original stays as it is"
			);
		}
		var result = { "saved": [], "skipped": [] };
		var readers = {};
		for ( var contentID in arguments.contentIDs ) {
			var content = "";
			if ( isSimpleValue( contentID ) && len( contentID ) ) {
				content = variables.contentService.get( id = contentID, returnNew = false );
			}
			if ( isNull( content ) || !isObject( content ) || content.getSite().getSiteID() != arguments.site.getSiteID() ) {
				result.skipped.append( { "contentID": contentID, "slug": "", "reason": "not found in this site" } );
				continue;
			}
			var item = convert( content, prepared.profile, prepared.types, readers );
			if ( !item.ready ) {
				result.skipped.append( { "contentID": item.contentID, "slug": item.slug, "reason": item.reason } );
				continue;
			}
			var loaded = variables.editor.load( content, arguments.author );
			var saved = variables.editor.save(
				content     = content,
				blocks      = item.sections.map( ( section ) => blockOf( section ) ),
				changelog   = variables.CHANGELOG & " (#prepared.profile.label#)",
				author      = arguments.author,
				baseVersion = loaded.content.version
			);
			if ( saved.saved ) {
				result.saved.append( { "contentID": item.contentID, "slug": item.slug } );
			} else {
				result.skipped.append( {
					"contentID": item.contentID,
					"slug"     : item.slug,
					"reason"   : saved.errors.map( ( error ) => error.message ).toList( "; " )
				} );
			}
		}
		return result;
	}

	/**
	 * The profile, the site's block types and what keeps the profile from being used on the site
	 *
	 * @types Block types instead of the site's (tests)
	 *
	 * @return { profile, types, problems: [], canApply }
	 */
	struct function prepare( required site, required string profile, struct types ) {
		var loaded = variables.profiles.get( arguments.profile );
		var problems = duplicate( loaded.problems );
		if ( len( loaded.theme ) && loaded.theme != arguments.site.getActiveTheme() ) {
			problems.append(
				"The profile is for the theme '#loaded.theme#', the site uses '#arguments.site.getActiveTheme()#'"
			);
		}
		var blockTypes = arguments.types ?: variables.registry.forSite( arguments.site );
		problems.append( checkRules( loaded, blockTypes ), true );
		return {
			"profile" : loaded,
			"types"   : blockTypes,
			"problems": problems,
			"canApply": loaded.compare == "markup" || variables.siteCopy.isCopy( arguments.site )
		};
	}

	/**
	 * Rules that do not fit the block types: unknown blocks or fields
	 */
	array function checkRules( required struct profile, required struct types ) {
		var problems = [];
		var index = 0;
		for ( var rule in arguments.profile.rules ) {
			index++;
			if ( !arguments.types.keyExists( rule.block ) ) {
				problems.append( "Rule #index#: the theme has no block '#rule.block#'" );
				continue;
			}
			if ( len( rule.match ) ) {
				try {
					variables.html.parse( "<div></div>" ).select( rule.match );
				} catch ( any e ) {
					problems.append( "Rule #index# (#rule.block#): invalid match selector '#rule.match#'" );
				}
			}
			problems.append(
				unknownFields( arguments.types[ rule.block ].fields, rule.fields, "Rule #index# (#rule.block#)" ),
				true
			);
		}
		return problems;
	}

	/**
	 * Convert one body
	 *
	 * @readers Code readers already created ({ name: instance }), shared between items
	 *
	 * @return { contentID, slug, title, contentType, ready, reason, sections: [ { type, data, source, rendered, same,
	 * note, errors: [], missing: [], canonical: { source, rendered } } ] } (missing for content, canonical for markup
	 * comparisons, both only when the part differs)
	 */
	struct function convert(
		required content,
		required struct profile,
		required struct types,
		struct readers = {}
	) {
		var body = arguments.content.getContent();
		var item = {
			"contentID"  : arguments.content.getContentID(),
			"slug"       : arguments.content.getSlug(),
			"title"      : arguments.content.getTitle(),
			"contentType": arguments.content.getContentType(),
			"sections"   : [],
			"ready"      : false,
			"reason"     : ""
		};
		if ( !len( trim( body ) ) ) {
			item.reason = "empty";
			return item;
		}
		if ( variables.format.parse( body ).some( ( block ) => block.status != "legacy" ) ) {
			item.reason = "already has blocks";
			return item;
		}

		for ( var source in sections( body ) ) {
			var matched = match(
				source,
				arguments.profile,
				arguments.types,
				arguments.readers
			);
			var previous = item.sections.len() ? item.sections[ item.sections.len() ] : {};
			if ( matched.type == "html" && ( previous.type ?: "" ) == "html" ) {
				previous.source &= chr( 10 ) & source;
				previous.data.html = previous.source;
				if ( len( matched.note ) ) {
					previous.note = listAppend( previous.note, matched.note, chr( 10 ) );
				}
				continue;
			}
			matched[ "id" ] = "c#item.sections.len() + 1#";
			matched[ "source" ] = source;
			item.sections.append( matched );
		}

		var rendered = variables.renderer.renderBlocks(
			arguments.content.getSite(),
			item.sections.map( ( section ) => blockOf( section ) ),
			arguments.types
		);
		var renderedByID = {};
		for ( var block in rendered.blocks ) {
			renderedByID[ block.id ] = block.html;
		}
		for ( var section in item.sections ) {
			var sectionID = section.id;
			section[ "rendered" ] = renderedByID[ sectionID ] ?: "";
			section[ "errors" ] = rendered.errors
				.filter( ( error ) => error.blockID == sectionID )
				.map( ( error ) => len( error.field ) ? error.field & ": " & error.message : error.message );
			section[ "missing" ] = [];
			section[ "same" ] = !section.errors.len() && renderedByID.keyExists( sectionID );
			if ( section.type == "html" ) {
				continue;
			}
			if ( arguments.profile.compare == "content" ) {
				section.missing = variables.html.missingContent( section.source, section.rendered );
				section.same = section.same && !section.missing.len();
			} else {
				var before = variables.html.canonical( section.source );
				var after = variables.html.canonical( section.rendered );
				if ( compare( before, after ) != 0 ) {
					section.same = false;
					section[ "canonical" ] = { "source": before, "rendered": after };
				}
			}
		}

		var different = item.sections.filter( ( section ) => !section.same ).len();
		var converted = item.sections.filter( ( section ) => section.type != "html" ).len();
		item.ready = different == 0 && converted > 0;
		if ( different ) {
			item.reason = different == 1 ? "1 section differs" : "#different# sections differ";
		} else if ( !converted ) {
			item.reason = "no section recognized";
		}
		return item;
	}

	/**
	 * Top-level parts of a body as HTML: elements, and widget calls ({{{...}}}) between them
	 */
	array function sections( required string body ) {
		var result = [];
		for ( var node in variables.html.children( variables.html.parse( arguments.body ) ) ) {
			if ( !variables.html.isText( node ) ) {
				result.append( node.outerHtml() );
				continue;
			}
			// Text between elements: one part per widget call, the rest as it is
			for ( var part in reMatch( "\{\{\{.*?\}\}\}|[^{]+|\{", trim( node.getWholeText() ) ) ) {
				if ( len( trim( part ) ) ) {
					result.append( trim( part ) );
				}
			}
		}
		return result;
	}

	/**
	 * The block for one part: { type, data, note } (note: why a part a rule matched stays HTML)
	 */
	struct function match(
		required string source,
		required struct profile,
		required struct types,
		struct readers = {}
	) {
		var store = reMatch( variables.STORE_CALL, arguments.source );
		if ( store.len() && arguments.types.keyExists( "contentStore" ) ) {
			return {
				"type": "contentStore",
				"data": { "slug": reReplace( arguments.source, variables.STORE_CALL, "\1" ) },
				"note": ""
			};
		}
		var nodes = variables.html.children( variables.html.parse( arguments.source ) );
		if ( nodes.len() == 1 && !variables.html.isText( nodes[ 1 ] ) ) {
			var element = nodes[ 1 ];
			for ( var rule in arguments.profile.rules ) {
				try {
					if ( len( rule.match ) && !element.is( rule.match ) ) {
						continue;
					}
					if ( len( rule.reader ) ) {
						if ( !arguments.readers.keyExists( rule.reader ) ) {
							arguments.readers[ rule.reader ] = variables.profiles.reader( arguments.profile, rule.reader );
						}
						// A reader returns nothing when the section is not its block
						local.data = arguments.readers[ rule.reader ].read( element, variables.reader );
						if ( isNull( local.data ) ) {
							continue;
						}
					} else {
						local.data = variables.reader.readFields(
							element,
							arguments.types[ rule.block ].fields,
							rule.fields
						);
					}
					return { "type": rule.block, "data": local.data, "note": "" };
				} catch ( Convert.Unconvertible e ) {
					return htmlPart( arguments.source, "#rule.block#: #e.message#" );
				}
			}
		}
		return htmlPart( arguments.source, "" );
	}

	/********************************* PRIVATE *********************************/

	/**
	 * Pages, blog entries and content store items of the site, by type and slug
	 */
	private array function contents( required site ) {
		var result = variables.contentService
			.newCriteria()
			.isEq( "site", arguments.site )
			.list( sortOrder = "slug asc" )
			.filter( ( content ) => listFindNoCase( variables.CONTENT_TYPES, content.getContentType() ) );
		// sort() changes the array (its return value differs between engines)
		result.sort( ( a, b ) => compareNoCase( a.getContentType() & "|" & a.getSlug(), b.getContentType() & "|" & b.getSlug() ) );
		return result;
	}

	private struct function htmlPart( required string source, required string note ) {
		return {
			"type": "html",
			"data": { "html": arguments.source },
			"note": arguments.note
		};
	}

	private struct function blockOf( required struct section ) {
		return {
			"type": arguments.section.type,
			"id"  : arguments.section.id ?: "",
			"data": arguments.section.data
		};
	}

	private struct function summary( required struct profile ) {
		return {
			"name"   : arguments.profile.name,
			"label"  : arguments.profile.label,
			"theme"  : arguments.profile.theme,
			"compare": arguments.profile.compare
		};
	}

	/**
	 * Field specs of a rule that the block does not have (list fields: their sub-fields too)
	 */
	private array function unknownFields( required array fields, required struct specs, required string label ) {
		var problems = [];
		var byName = {};
		for ( var field in arguments.fields ) {
			byName[ field.name ] = field;
		}
		for ( var name in arguments.specs ) {
			if ( !byName.keyExists( name ) ) {
				problems.append( "#arguments.label#: the block has no field '#name#'" );
				continue;
			}
			var spec = arguments.specs[ name ];
			if ( byName[ name ].type == "list" && isStruct( spec ) && isStruct( spec.fields ?: "" ) ) {
				problems.append(
					unknownFields( byName[ name ].fields ?: [], spec.fields, "#arguments.label#, #name#" ),
					true
				);
			}
		}
		return problems;
	}

}
