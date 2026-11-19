/**
 * args.studio for previews in the editor canvas: like TemplateHelper, but text a template outputs unchanged from a
 * text or textarea field (through esc() or nl2br()) is wrapped in <span data-cbs-field="path">, so the editor can
 * make it editable in place. Saved HTML never goes through this helper.
 *
 * Values are matched exactly (case-sensitive); a value that several fields share is not marked, so a span always
 * names the right field. Text a template changes first (trim, split, ...) is not marked and is edited in the panel.
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
		return variables.helper.richText( arguments.doc );
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
		var key = toString( arguments.text );
		if ( variables.ambiguous.contains( key ) || !variables.paths.containsKey( key ) ) {
			return "";
		}
		return variables.paths.get( key );
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

	/**
	 * Text and textarea values by path; list items are numbered from 0, like the editor's data
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
				var key = toString( value );
				if ( variables.paths.containsKey( key ) ) {
					variables.ambiguous.add( key );
				} else {
					variables.paths.put( key, path );
				}
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