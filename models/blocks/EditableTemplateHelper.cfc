/**
 * args.studio for previews in the editor canvas: like TemplateHelper, but text a template outputs unchanged from a
 * text or textarea field (through esc() or nl2br()) is wrapped in <span data-cbs-field="path">, and a rich text
 * field's HTML (through richText()) in <div data-cbs-field="path">, so the editor can make it editable in place.
 * Saved HTML never goes through this helper.
 *
 * Values are matched exactly (case-sensitive, rich text by its document); a value that several fields share is not
 * marked, so a mark always names the right field. Text a template changes first (trim, split, ...) is not marked
 * and is edited in the panel.
 */
component {

	/**
	 * @helper The TemplateHelper
	 * @fields Normalized field definitions of the block
	 * @data   Normalized data of the block
	 */
	function init(
		required helper,
		required array fields,
		required struct data
	) {
		variables.helper = arguments.helper;
		// Java map: struct keys in CFML are case-insensitive
		variables.paths = createObject( "java", "java.util.HashMap" ).init();
		variables.ambiguous = createObject( "java", "java.util.HashSet" ).init();
		collect(
			arguments.fields,
			arguments.data,
			""
		);
		return this;
	}

	string function esc( any text = "" ) {
		return mark(
			arguments.text,
			variables.helper.esc( arguments.text ),
			"text"
		);
	}

	string function nl2br( any text = "" ) {
		return mark(
			arguments.text,
			variables.helper.nl2br( arguments.text ),
			"textarea"
		);
	}

	string function attr( any text = "" ) {
		return variables.helper.attr( arguments.text );
	}

	string function richText( any doc = "" ) {
		var html = variables.helper.richText( arguments.doc );
		var path = docPathOf( arguments.doc );
		if ( !len( path ) ) {
			return html;
		}
		return "<div data-cbs-field=""#path#"" data-cbs-type=""richtext"">#html#</div>";
	}

	string function src( any source = "" ) {
		return variables.helper.src( arguments.source );
	}

	string function linkAttrs( any link = {} ) {
		return variables.helper.linkAttrs( arguments.link );
	}

	string function contentStore( any slug = "" ) {
		return variables.helper.contentStore( arguments.slug );
	}

	/**
	 * Path (e.g. "title", "steps.0.title") of a field with exactly this value, "" if none or several
	 */
	string function pathOf( any text = "" ) {
		if ( !isSimpleValue( arguments.text ) ) {
			return "";
		}
		return lookup( toString( arguments.text ) );
	}

	/**
	 * Path of a rich text field with exactly this document, "" if none or several
	 */
	string function docPathOf( any doc = "" ) {
		return lookup( docKey( arguments.doc ) );
	}

	private string function mark(
		any text,
		required string html,
		required string type
	) {
		var path = pathOf( arguments.text );
		if ( !len( path ) ) {
			return arguments.html;
		}
		return "<span data-cbs-field=""#path#"" data-cbs-type=""#arguments.type#"">#arguments.html#</span>";
	}

	private string function lookup( required string key ) {
		if ( !len( arguments.key ) || variables.ambiguous.contains( arguments.key ) || !variables.paths.containsKey( arguments.key ) ) {
			return "";
		}
		return variables.paths.get( arguments.key );
	}

	/**
	 * Map key of a rich text document with content, "" for anything else; the prefix keeps documents apart from text
	 */
	private string function docKey( any doc ) {
		if (
			isNull( arguments.doc ) || !isStruct( arguments.doc ) || !arguments.doc.keyExists( "content" ) || !isArray(
				arguments.doc.content
			) || !arguments.doc.content.len()
		) {
			return "";
		}
		return "richtext:" & serializeJSON( arguments.doc );
	}

	private void function add( required string key, required string path ) {
		if ( variables.paths.containsKey( arguments.key ) ) {
			variables.ambiguous.add( arguments.key );
		} else {
			variables.paths.put( arguments.key, arguments.path );
		}
	}

	/**
	 * Text, textarea and rich text values by path; list items are numbered from 0, like the editor's data
	 */
	private void function collect(
		required array fields,
		required struct data,
		required string prefix
	) {
		for ( var field in arguments.fields ) {
			if ( !arguments.data.keyExists( field.name ) || isNull( arguments.data[ field.name ] ) ) {
				continue;
			}
			var value = arguments.data[ field.name ];
			var path = arguments.prefix & field.name;
			if ( listFindNoCase( "text,textarea", field.type ) && isSimpleValue( value ) && len( trim( value ) ) ) {
				add( toString( value ), path );
			} else if ( field.type == "richtext" && len( docKey( value ) ) ) {
				add( docKey( value ), path );
			} else if ( field.type == "list" && isArray( value ) ) {
				for ( var i = 1; i <= value.len(); i++ ) {
					if ( isStruct( value[ i ] ) ) {
						collect(
							field.fields,
							value[ i ],
							path & "." & ( i - 1 ) & "."
						);
					}
				}
			}
		}
	}

}