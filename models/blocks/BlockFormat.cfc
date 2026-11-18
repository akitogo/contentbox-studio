/**
 * Block format, version 1: blocks as HTML comments with JSON data inside the content body.
 * Specification: docs/block-format.md. TypeScript counterpart: ui/src/blocks/format.ts.
 * Both are tested against tests/fixtures/block-format/.
 *
 * Parsed block: { type, v, id, data, html, status } with status ok | modified | invalid | legacy.
 * Block to write: { type, v (optional), id, data, html }.
 */
component singleton {

	variables.TYPE_PATTERN = "^[A-Za-z][A-Za-z0-9_-]*$";
	variables.ID_PATTERN   = "^[A-Za-z0-9_-]{1,32}$";
	variables.LF           = chr( 10 );
	variables.CRLF         = chr( 13 ) & chr( 10 );

	function init(){
		// java.util.regex: same behaviour on every engine
		var pattern               = createObject( "java", "java.util.regex.Pattern" );
		variables.openMarker      = pattern.compile( "<!--\s*cb:block\s+([^>]*?)\s*-->" );
		variables.closeMarker     = pattern.compile( "<!--\s*/cb:block\s*-->" );
		variables.markerLike      = pattern.compile( "<!--(\s*/?)cb:block" );
		variables.edgeWhitespace  = pattern.compile( "^[ \t\r\n]+|[ \t\r\n]+$" );
		variables.javaInteger     = createObject( "java", "java.lang.Integer" );
		return this;
	}

	/**
	 * Java String.hashCode of the text as 8 lowercase hex digits (unsigned)
	 */
	string function hashHtml( required string html ){
		var hex = variables.javaInteger.toHexString( javacast( "string", arguments.html ).hashCode() );
		return repeatString( "0", 8 - len( hex ) ) & hex;
	}

	/**
	 * JSON for the opening marker: nothing that ends the comment or triggers ContentBox's renderers
	 */
	string function escapeEnvelope( required string json ){
		// Built with chr( 92 ): BoxLang decodes \uXXXX inside CFML string literals, Adobe does not
		var u       = chr( 92 ) & "u";
		var escaped = replace( arguments.json, "<", u & "003c", "all" );
		escaped     = replace( escaped, ">", u & "003e", "all" );
		escaped     = replace( escaped, "&", u & "0026", "all" );
		escaped     = replace( escaped, "--", u & "002d" & u & "002d", "all" );
		return replace( escaped, "{{", u & "007b" & u & "007b", "all" );
	}

	/**
	 * Renames marker-like comments inside block HTML (cb:block -> cb-block) so blocks cannot nest
	 */
	string function neutralizeMarkers( required string html ){
		return variables.markerLike.matcher( arguments.html ).replaceAll( "<!--$1cb-block" );
	}

	boolean function isValidType( required string type ){
		return reFind( variables.TYPE_PATTERN, arguments.type ) > 0;
	}

	boolean function isValidId( required string id ){
		return reFind( variables.ID_PATTERN, arguments.id ) > 0;
	}

	/**
	 * @blocks Array of { type, v (optional), id, data, html }
	 */
	string function serialize( required array blocks ){
		return arguments.blocks
			.map( ( block ) => {
				if ( !isValidType( block.type ) || !isValidId( block.id ) ) {
					throw(
						type    = "BlockFormat.InvalidBlock",
						message = "Invalid block type or id: [#block.type#] [#block.id#]"
					);
				}
				var html     = neutralizeMarkers( block.html );
				// type and id match their patterns, so they need no JSON escaping
				var envelope = "{""type"":""#block.type#"",""v"":#int( block.v ?: 1 )#,""id"":""#block.id#"",""hash"":""#hashHtml( html )#"",""data"":#block.type == "html" ? "{}" : serializeJSON( block.data ?: {} )#}";
				return "<!-- cb:block #escapeEnvelope( envelope )# -->#variables.LF##html##variables.LF#<!-- /cb:block -->";
			} )
			.toList( variables.LF & variables.LF );
	}

	/**
	 * @return Array of { type, v, id, data, html, status }
	 */
	array function parse( required string body ){
		var state = { "blocks" : [], "generated" : 0 };
		var text  = arguments.body;
		var total = len( text );

		var position = 0;
		while ( position < total ) {
			var open = findMarker( variables.openMarker, text, position );
			if ( isNull( open ) ) {
				addOutsideText( state, substring( text, position, total ) );
				break;
			}
			addOutsideText( state, substring( text, position, open.index ) );

			var close     = findMarker( variables.closeMarker, text, open.end );
			var nextOpen  = findMarker( variables.openMarker, text, open.end );
			if ( isNull( close ) || ( !isNull( nextOpen ) && nextOpen.index < close.index ) ) {
				state.blocks.append(
					htmlBlock( state, trimEdges( substring( text, open.index, total ) ), "legacy" )
				);
				break;
			}

			var html  = innerHtml( substring( text, open.end, close.index ) );
			var block = readBlock( open.json, html );
			state.blocks.append( isNull( block ) ? htmlBlock( state, html, "invalid" ) : block );
			position = close.end;
		}

		return state.blocks;
	}

	/********************************* PRIVATE *********************************/

	/**
	 * @return { index, end, json } with 0-based Java indexes, or null
	 */
	private function findMarker( required pattern, required string text, required numeric from ){
		var matcher = arguments.pattern.matcher( arguments.text );
		if ( !matcher.find( javacast( "int", arguments.from ) ) ) {
			return;
		}
		return {
			"index" : matcher.start(),
			"end"   : matcher.end(),
			"json"  : matcher.groupCount() ? ( matcher.group( javacast( "int", 1 ) ) ?: "" ) : ""
		};
	}

	/**
	 * Java-style substring with 0-based start (inclusive) and end (exclusive)
	 */
	private string function substring( required string text, required numeric start, required numeric end ){
		return arguments.end > arguments.start ? mid( arguments.text, arguments.start + 1, arguments.end - arguments.start ) : "";
	}

	private string function trimEdges( required string text ){
		return variables.edgeWhitespace.matcher( arguments.text ).replaceAll( "" );
	}

	/**
	 * Without one line break after the opening and one before the closing marker
	 */
	private string function innerHtml( required string raw ){
		var html = arguments.raw;
		if ( left( html, 2 ) == variables.CRLF ) {
			html = mid( html, 3, len( html ) );
		} else if ( left( html, 1 ) == variables.LF ) {
			html = mid( html, 2, len( html ) );
		}
		if ( right( html, 2 ) == variables.CRLF ) {
			html = left( html, len( html ) - 2 );
		} else if ( right( html, 1 ) == variables.LF ) {
			html = left( html, len( html ) - 1 );
		}
		return html;
	}

	private void function addOutsideText( required struct state, required string text ){
		var html = trimEdges( arguments.text );
		if ( len( html ) ) {
			arguments.state.blocks.append( htmlBlock( arguments.state, html, "legacy" ) );
		}
	}

	private struct function htmlBlock( required struct state, required string html, required string status ){
		arguments.state.generated++;
		return {
			"type"   : "html",
			"v"      : 1,
			"id"     : "legacy-#arguments.state.generated#",
			"data"   : { "html" : arguments.html },
			"html"   : arguments.html,
			"status" : arguments.status
		};
	}

	private function readBlock( required string json, required string html ){
		try {
			var envelope = deserializeJSON( arguments.json );
		} catch ( any e ) {
			return;
		}
		if (
			!isStruct( envelope )
			|| !envelope.keyExists( "type" ) || !isSimpleValue( envelope.type ) || !isValidType( envelope.type )
			|| !envelope.keyExists( "id" ) || !isSimpleValue( envelope.id ) || !isValidId( envelope.id )
		) {
			return;
		}

		var data = envelope.keyExists( "data" ) && isStruct( envelope.data ) ? duplicate( envelope.data ) : {};
		if ( envelope.type == "html" ) {
			data[ "html" ] = arguments.html;
		}
		var v = envelope.keyExists( "v" ) && isNumeric( envelope.v ) && int( envelope.v ) == envelope.v && envelope.v > 0 ? int(
			envelope.v
		) : 1;
		var modified = envelope.keyExists( "hash" ) && isSimpleValue( envelope.hash ) && compare(
			envelope.hash,
			hashHtml( arguments.html )
		) != 0;

		return {
			"type"   : envelope.type,
			"v"      : v,
			"id"     : envelope.id,
			"data"   : data,
			"html"   : arguments.html,
			"status" : modified ? "modified" : "ok"
		};
	}

}
