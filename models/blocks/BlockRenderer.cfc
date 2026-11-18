/**
 * Renders blocks into the HTML stored in the content body.
 *
 * The server renders on save, so the stored body is always complete HTML. Each block type's render.cfm gets:
 * args.data    normalized field values
 * args.block   { id, type }
 * args.studio  TemplateHelper (escaping, rich text, links, images, content store)
 * args.site    the site the content belongs to
 */
component singleton {
	property name="registry" inject="BlockRegistry@contentbox-studio";

	property name="blockData" inject="BlockData@contentbox-studio";

	property name="format" inject="BlockFormat@contentbox-studio";

	property name="helper" inject="TemplateHelper@contentbox-studio";

	/**
	 * Render blocks from the editor
	 *
	 * @site   The site, for its theme's block types
	 * @blocks Array of { type, id (optional), data }
	 * @types  Block types to use instead of the site's (tests, previews of other themes)
	 *
	 * @return { body, blocks: [ { type, v, id, data, html, errors } ], errors: [ { blockID, field, message } ] }
	 */
	struct function renderBlocks(
		required site,
		required array blocks,
		struct types
	) {
		var blockTypes = arguments.types ?: variables.registry.forSite( arguments.site );
		var usedIDs = {};
		var result = { "blocks": [], "errors": [] };

		for ( var input in arguments.blocks ) {
			if ( isNull( input ) || !isStruct( input ) ) {
				result.errors.append(
					{
						"blockID": "",
						"field"  : "",
						"message": "A block must be an object"
					}
				);
				continue;
			}
			var type = textOf( input, "type" );
			if ( !len( type ) || !blockTypes.keyExists( type ) ) {
				result.errors.append(
					{
						"blockID": textOf( input, "id" ),
						"field"  : "",
						"message": "Unknown block type [#type#]"
					}
				);
				continue;
			}
			var definition = blockTypes[ type ];
			var id = textOf( input, "id" );
			if ( !variables.format.isValidId( id ) || usedIDs.keyExists( id ) ) {
				id = newId( usedIDs );
			}
			usedIDs[ id ] = true;

			var normalized = variables.blockData.normalize( definition.fields, input.data ?: {} );
			result.blocks.append(
				{
					"type": definition.name,
					"v"   : definition.version,
					"id"  : id,
					"data": normalized.data,
					"html": renderBlock(
						definition,
						normalized.data,
						{ "id": id, "site": arguments.site }
					),
					"errors": normalized.errors
				}
			);
			for ( var error in normalized.errors ) {
				result.errors.append(
					{
						"blockID": id,
						"field"  : error.field,
						"message": error.message
					}
				);
			}
		}

		result[ "body" ] = variables.format.serialize( result.blocks );
		return result;
	}

	/**
	 * @definition A block type from the registry
	 * @data       Normalized data
	 * @context    { id, site }
	 */
	string function renderBlock(
		required struct definition,
		required struct data,
		struct context = {}
	) {
		if ( arguments.definition.name == "html" ) {
			return arguments.data.html ?: "";
		}
		var args = {
			"data" : arguments.data,
			"block": {
				"id"  : arguments.context.id ?: "",
				"type": arguments.definition.name
			},
			"studio": variables.helper,
			"site"  : arguments.context.site ?: ""
		};
		savecontent variable="local.html" {
			include "#arguments.definition.renderTemplate#";
		}
		return trim( html );
	}

	/**
	 * Re-render a stored body with the current block templates, e.g. after a theme update.
	 * Only bodies Studio wrote are touched: without blocks, or with blocks changed outside Studio (modified, invalid),
	 * the body is returned unchanged. Legacy parts and block types the site no longer has keep their HTML.
	 *
	 * @return { body, changed (number of blocks with new HTML), skipped ("" or the reason) }
	 */
	struct function rerenderBody(
		required site,
		required string body,
		struct types
	) {
		var parsed = variables.format.parse( arguments.body );
		if (
			parsed.some(
				( block ) => block.status == "modified" || block.status == "invalid"
			)
		) {
			return {
				"body"   : arguments.body,
				"changed": 0,
				"skipped": "blocks changed outside Studio"
			};
		}
		if (
			!parsed.some(
				( block ) => block.status == "ok" && left( block.id, 7 ) != "legacy-"
			)
		) {
			return {
				"body"   : arguments.body,
				"changed": 0,
				"skipped": "no blocks"
			};
		}

		var blockTypes = arguments.types ?: variables.registry.forSite( arguments.site );
		var changed = 0;
		var blocks = [];
		for ( var block in parsed ) {
			var html = block.html;
			var data = block.data;
			if ( block.status == "ok" && block.type != "html" && blockTypes.keyExists( block.type ) ) {
				var normalized = variables.blockData.normalize( blockTypes[ block.type ].fields, block.data );
				data = normalized.data;
				html = renderBlock(
					blockTypes[ block.type ],
					data,
					{ "id": block.id, "site": arguments.site }
				);
				if ( compare( html, block.html ) != 0 ) {
					changed++;
				}
			}
			blocks.append(
				{
					"type": block.type,
					"v"   : block.v,
					"id"  : block.id,
					"data": data,
					"html": html
				}
			);
		}
		return {
			"body"   : variables.format.serialize( blocks ),
			"changed": changed,
			"skipped": ""
		};
	}

	/**
	 * A random block id, unique among the given ids
	 */
	string function newId( struct usedIDs = {} ) {
		var chars = "abcdefghijklmnopqrstuvwxyz0123456789";
		do {
			var id = "";
			for ( var i = 1; i <= 8; i++ ) {
				id &= mid(
					chars,
					randRange(
						1,
						36,
						"SHA1PRNG"
					),
					1
				);
			}
		} while ( arguments.usedIDs.keyExists( id ) );
		return id;
	}

	/**
	 * A simple value of untrusted input as string, or ""
	 */
	private string function textOf( required struct input, required string key ) {
		if ( !arguments.input.keyExists( arguments.key ) || isNull( arguments.input[ arguments.key ] ) ) {
			return "";
		}
		var value = arguments.input[ arguments.key ];
		return isSimpleValue( value ) ? toString( value ) : "";
	}

}