/**
 * Field definitions of block types (block.json) and the data of blocks.
 *
 * - normalizeFields(): checks and completes the "fields" of a block.json when the registry loads it
 * - normalize(): turns untrusted block data (from the editor or a stored body) into exactly the fields of the
 * block type, with the right types and safe URLs, and reports what is wrong
 *
 * Field types: text, textarea, richtext, number, boolean, select, link, image, images, html, contentStore, list
 */
component singleton {
	property name="markup" inject="Markup@contentbox-studio";

	property name="richText" inject="RichText@contentbox-studio";
	variables.FIELD_TYPES = [
		"text",
		"textarea",
		"richtext",
		"number",
		"boolean",
		"select",
		"link",
		"image",
		"images",
		"html",
		"contentStore",
		"list"
	];
	variables.NAME_PATTERN = "^[A-Za-z][A-Za-z0-9_]*$";
	variables.SLUG_PATTERN = "^[A-Za-z0-9_/-]+$";

	array function getFieldTypes() {
		return variables.FIELD_TYPES;
	}

	/**
	 * Check and complete field definitions
	 *
	 * @fields    The "fields" array of a block.json
	 * @blockName For error messages
	 *
	 * @throws BlockDefinition.InvalidField
	 */
	array function normalizeFields( any fields = [], string blockName = "" ) {
		if ( !isArray( arguments.fields ) ) {
			invalidField( arguments.blockName, "fields must be an array" );
		}
		var names = {};
		return arguments.fields.map(
			( field ) => {
				if (
					!isStruct( field ) || !isSimpleValue( field.name ?: [] ) ||
						!reFind( variables.NAME_PATTERN, field.name ?: "" )
				) {
					invalidField(
						blockName,
						"every field needs a name matching #variables.NAME_PATTERN#"
					);
				}
				if ( names.keyExists( field.name ) ) {
					invalidField( blockName, "duplicate field [#field.name#]" );
				}
				names[ field.name ] = true;
				if ( !variables.FIELD_TYPES.findNoCase( field.type ?: "" ) ) {
					invalidField(
						blockName,
						"field [#field.name#] has unknown type [#field.type ?: ""#]"
					);
				}

				var normalized = {
					"name"    : field.name,
					"type"    : variables.FIELD_TYPES[ variables.FIELD_TYPES.findNoCase( field.type ) ],
					"label"   : field.label ?: field.name,
					"help"    : field.help ?: "",
					"required": isTrue( field.required ?: false )
				};
				switch ( normalized.type ) {
					case "select":
						if ( !isArray( field.options ?: "" ) || !field.options.len() ) {
							invalidField( blockName, "select field [#field.name#] needs options" );
						}
						normalized[ "options" ] = field.options.map(
							( option ) => {
								return isStruct( option )
									? {
										"value": toString( option.value ?: "" ),
										"label": toString( option.label ?: option.value ?: "" )
									}
									: {
										"value": toString( option ),
										"label": toString( option )
									};
							}
						);
						break;
					case "list":
						normalized[ "fields" ] = normalizeFields( field.fields ?: "", "#blockName#.#field.name#" );
						break;
				}
				for ( var limit in [ "maxLength", "maxItems", "min", "max" ] ) {
					if ( field.keyExists( limit ) && isNumeric( field[ limit ] ) ) {
						normalized[ limit ] = field[ limit ];
					}
				}
				normalized[ "default" ] = field.keyExists( "default" ) ? field.default : typeDefault( normalized.type );
				return normalized;
			}
		);
	}

	/**
	 * @fields Normalized field definitions
	 * @data   Untrusted block data
	 * @path   Prefix for error field paths (lists)
	 *
	 * @return { data, errors: [ { field, message } ] }
	 */
	struct function normalize(
		required array fields,
		any data    = {},
		string path = ""
	) {
		var input = isNull( arguments.data ) || !isStruct( arguments.data ) ? {} : arguments.data;
		var result = { "data": {}, "errors": [] };

		for ( var field in arguments.fields ) {
			var fieldPath = arguments.path & field.name;
			var raw = input.keyExists( field.name ) && !isNull( input[ field.name ] )
				? input[ field.name ]
				: duplicate( field.default );
			// result is a struct, so passed by reference on every engine (Adobe ColdFusion copies arrays)
			var value = normalizeValue(
				field,
				raw,
				fieldPath,
				result
			);
			if ( field.required && isEmptyValue( field, value ) ) {
				result.errors.append(
					{
						"field"  : fieldPath,
						"message": "#field.label# is required"
					}
				);
			}
			result.data[ field.name ] = value;
		}

		return result;
	}

	/********************************* PRIVATE *********************************/

	private any function normalizeValue(
		required struct field,
		any raw,
		required string path,
		required struct collector
	) {
		var value = isNull( arguments.raw ) ? "" : arguments.raw;

		switch ( arguments.field.type ) {
			case "text":
				return checkLength(
					arguments.field,
					reReplace(
						toText( value ),
						"[\r\n]+",
						" ",
						"all"
					),
					arguments.path,
					arguments.collector
				);
			case "textarea":
				return checkLength(
					arguments.field,
					reReplace(
						toText( value ),
						"\r\n?",
						chr( 10 ),
						"all"
					),
					arguments.path,
					arguments.collector
				);
			case "html":
				return toText( value );
			case "richtext":
				return variables.richText.normalize( value );
			case "number":
				if ( !isSimpleValue( value ) || !isNumeric( value ) ) {
					if ( isSimpleValue( value ) && len( trim( value ) ) ) {
						arguments
							.collector
							.errors
							.append(
								{
									"field"  : arguments.path,
									"message": "#arguments.field.label# must be a number"
								}
							);
					}
					return "";
				}
				if ( arguments.field.keyExists( "min" ) && value < arguments.field.min ) {
					arguments
						.collector
						.errors
						.append(
							{
								"field"  : arguments.path,
								"message": "#arguments.field.label# must be at least #arguments.field.min#"
							}
						);
				}
				if ( arguments.field.keyExists( "max" ) && value > arguments.field.max ) {
					arguments
						.collector
						.errors
						.append(
							{
								"field"  : arguments.path,
								"message": "#arguments.field.label# must be at most #arguments.field.max#"
							}
						);
				}
				return val( value );
			case "boolean":
				return isSimpleValue( value ) && isBoolean( value ) && value;
			case "select":
				var choice = toText( value );
				if (
					len( choice ) &&
						!arguments
							.field
							.options
							.some( ( option ) => compare( option.value, choice ) == 0 )
				) {
					arguments
						.collector
						.errors
						.append(
							{
								"field"  : arguments.path,
								"message": "#arguments.field.label#: [#choice#] is not one of the options"
							}
						);
					return toText( arguments.field.default );
				}
				return choice;
			case "link":
				var link = isStruct( value ) ? value : { "href": toText( value ) };
				var href = toText( link.href ?: "" );
				var safe = variables.markup.safeUrl( href );
				if ( len( trim( href ) ) && !len( safe ) ) {
					arguments
						.collector
						.errors
						.append(
							{
								"field"  : arguments.path,
								"message": "#arguments.field.label#: the link [#href#] is not allowed"
							}
						);
				}
				return {
					"href"  : safe,
					"target": toText( link.target ?: "" ) == "_blank" ? "_blank" : ""
				};
			case "image":
				return normalizeImage(
					arguments.field,
					value,
					arguments.path,
					arguments.collector
				);
			case "images":
				var images = isArray( value ) ? value : [];
				var list = [];
				for ( var i = 1; i <= images.len(); i++ ) {
					var image = normalizeImage(
						arguments.field,
						images[ i ],
						"#arguments.path#[#i#]",
						arguments.collector
					);
					if ( len( image.src ) ) {
						list.append( image );
					}
				}
				return checkItems(
					arguments.field,
					list,
					arguments.path,
					arguments.collector
				);
			case "contentStore":
				var slug = trim( toText( value ) );
				if ( len( slug ) && !reFind( variables.SLUG_PATTERN, slug ) ) {
					arguments
						.collector
						.errors
						.append(
							{
								"field"  : arguments.path,
								"message": "#arguments.field.label#: [#slug#] is not a valid slug"
							}
						);
					return "";
				}
				return slug;
			case "list":
				var items = isArray( value ) ? value : [];
				var result = [];
				for ( var i = 1; i <= items.len(); i++ ) {
					var item = normalize(
						arguments.field.fields,
						isNull( items[ i ] ) ? {} : items[ i ],
						"#arguments.path#[#i#]."
					);
					arguments
						.collector
						.errors
						.append( item.errors, true );
					result.append( item.data );
				}
				return checkItems(
					arguments.field,
					result,
					arguments.path,
					arguments.collector
				);
		}
	}

	private struct function normalizeImage(
		required struct field,
		any value,
		required string path,
		required struct collector
	) {
		var image = !isNull( arguments.value ) && isStruct( arguments.value )
			? arguments.value
			: { "src": toText( arguments.value ?: "" ) };
		var src = toText( image.src ?: "" );
		var safe = variables.markup.safeImageUrl( src );
		if ( len( trim( src ) ) && !len( safe ) ) {
			arguments
				.collector
				.errors
				.append(
					{
						"field"  : arguments.path,
						"message": "#arguments.field.label#: the image URL [#src#] is not allowed"
					}
				);
		}
		var result = { "src": safe, "alt": toText( image.alt ?: "" ) };
		for ( var dimension in [ "width", "height" ] ) {
			if (
				image.keyExists( dimension ) && isSimpleValue( image[ dimension ] ) &&
						isNumeric( image[ dimension ] ) &&
					image[ dimension ] > 0
			) {
				result[ dimension ] = int( image[ dimension ] );
			}
		}
		return result;
	}

	private string function checkLength(
		required struct field,
		required string value,
		required string path,
		required struct collector
	) {
		if ( ( arguments.field.maxLength ?: 0 ) > 0 && len( arguments.value ) > arguments.field.maxLength ) {
			arguments
				.collector
				.errors
				.append(
					{
						"field"  : arguments.path,
						"message": "#arguments.field.label# is longer than #arguments.field.maxLength# characters"
					}
				);
		}
		return arguments.value;
	}

	private array function checkItems(
		required struct field,
		required array items,
		required string path,
		required struct collector
	) {
		if ( ( arguments.field.maxItems ?: 0 ) > 0 && arguments.items.len() > arguments.field.maxItems ) {
			arguments
				.collector
				.errors
				.append(
					{
						"field"  : arguments.path,
						"message": "#arguments.field.label# has more than #arguments.field.maxItems# items"
					}
				);
		}
		return arguments.items;
	}

	private boolean function isEmptyValue( required struct field, any value ) {
		var type = arguments.field.type;
		if ( type == "richtext" ) {
			return variables.richText.isEmpty( arguments.value );
		}
		if ( type == "link" ) {
			return !len( arguments.value.href );
		}
		if ( type == "image" ) {
			return !len( arguments.value.src );
		}
		if ( type == "images" || type == "list" ) {
			return !arguments.value.len();
		}
		if ( type == "boolean" ) {
			return false;
		}
		if ( type == "number" ) {
			return !isNumeric( arguments.value );
		}
		var empty = !len( trim( arguments.value ) );
		return empty;
	}

	private any function typeDefault( required string type ) {
		switch ( arguments.type ) {
			case "richtext":
				return variables.richText.emptyDoc();
			case "boolean":
				return false;
			case "link":
				return { "href": "", "target": "" };
			case "image":
				return { "src": "", "alt": "" };
			case "images":

			case "list":
				return [];
			default:
				return "";
		}
	}

	private boolean function isTrue( any value ) {
		return !isNull( arguments.value ) && isSimpleValue( arguments.value ) && isBoolean( arguments.value ) &&
			arguments.value;
	}

	private string function toText( any value ) {
		return !isNull( arguments.value ) && isSimpleValue( arguments.value ) ? toString( arguments.value ) : "";
	}

	private void function invalidField(
		required string blockName,
		required string message
	) {
		throw(
			type    = "BlockDefinition.InvalidField",
			message = "Block [#arguments.blockName#]: #arguments.message#"
		);
	}

}