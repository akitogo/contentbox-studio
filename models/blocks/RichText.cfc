/**
 * Rich text fields store a ProseMirror document (what TipTap produces), not HTML.
 *
 * normalize() keeps only the allowed nodes, marks and attributes; toHTML() renders the HTML itself, escaping all text.
 * So rich text can never carry arbitrary HTML, script or event attributes, and no HTML sanitizer is needed.
 *
 * Nodes: paragraph, heading (level 1-6), bulletList, orderedList (start), listItem, blockquote, hardBreak,
 * horizontalRule, text. Marks: bold, italic, underline, strike, code, subscript, superscript, link (href, target).
 * Unknown nodes are replaced by their content, unknown marks dropped.
 */
component singleton {
	property name="markup" inject="Markup@contentbox-studio";
	variables.CONTAINERS = {
		"paragraph"  : "p",
		"blockquote" : "blockquote",
		"bulletList" : "ul",
		"orderedList": "ol",
		"listItem"   : "li"
	};
	variables.MARKS = {
		"bold"       : "strong",
		"italic"     : "em",
		"underline"  : "u",
		"strike"     : "s",
		"code"       : "code",
		"subscript"  : "sub",
		"superscript": "sup"
	};

	struct function emptyDoc() {
		return { "type": "doc", "content": [] };
	}

	/**
	 * @doc A ProseMirror document (struct) or anything else (gives an empty document)
	 */
	struct function normalize( any doc ) {
		if ( isNull( arguments.doc ) || !isStruct( arguments.doc ) || !arguments.doc.keyExists( "content" ) ) {
			return emptyDoc();
		}
		return {
			"type"   : "doc",
			"content": normalizeNodes( arguments.doc.content )
		};
	}

	/**
	 * True if the document has no text and no horizontal rule
	 */
	boolean function isEmpty( any doc ) {
		return !len( trim( plainText( normalize( arguments.doc ?: "" ) ) ) );
	}

	string function toHTML( any doc ) {
		return renderNodes( normalize( arguments.doc ?: "" ).content );
	}

	/********************************* PRIVATE *********************************/

	private array function normalizeNodes( any nodes ) {
		var result = [];
		if ( !isArray( arguments.nodes ) ) {
			return result;
		}
		for ( var node in arguments.nodes ) {
			if ( isNull( node ) || !isStruct( node ) || !node.keyExists( "type" ) || !isSimpleValue( node.type ) ) {
				continue;
			}
			switch ( node.type ) {
				case "text":
					if ( node.keyExists( "text" ) && isSimpleValue( node.text ) && len( node.text ) ) {
						var textNode = { "type": "text", "text": toString( node.text ) };
						var marks = normalizeMarks( node.marks ?: [] );
						if ( marks.len() ) {
							textNode[ "marks" ] = marks;
						}
						result.append( textNode );
					}
					break;
				case "hardBreak":

				case "horizontalRule":
					result.append( { "type": node.type } );
					break;
				case "heading":
					result.append(
						{
							"type" : "heading",
							"attrs": {
								"level": clampInt(
									attr(
										node,
										"level",
										2
									),
									1,
									6,
									2
								)
							},
							"content": normalizeNodes( node.content ?: [] )
						}
					);
					break;
				case "orderedList":
					result.append(
						{
							"type" : "orderedList",
							"attrs": {
								"start": clampInt(
									attr(
										node,
										"start",
										1
									),
									1,
									1000000,
									1
								)
							},
							"content": normalizeNodes( node.content ?: [] )
						}
					);
					break;
				default:
					if ( variables.CONTAINERS.keyExists( node.type ) ) {
						result.append(
							{
								"type"   : node.type,
								"content": normalizeNodes( node.content ?: [] )
							}
						);
					} else {
						// Unknown node: keep its content
						result.append( normalizeNodes( node.content ?: [] ), true );
					}
			}
		}
		return result;
	}

	private array function normalizeMarks( any marks ) {
		var result = [];
		if ( !isArray( arguments.marks ) ) {
			return result;
		}
		for ( var mark in arguments.marks ) {
			if ( isNull( mark ) || !isStruct( mark ) || !mark.keyExists( "type" ) || !isSimpleValue( mark.type ) ) {
				continue;
			}
			if ( variables.MARKS.keyExists( mark.type ) ) {
				result.append( { "type": mark.type } );
			} else if ( mark.type == "link" ) {
				var href = variables.markup.safeUrl( attr( mark, "href" ) );
				if ( len( href ) ) {
					var attrs = { "href": href };
					if ( attr( mark, "target" ) == "_blank" ) {
						attrs[ "target" ] = "_blank";
					}
					result.append( { "type": "link", "attrs": attrs } );
				}
			}
		}
		return result;
	}

	private string function renderNodes( required array nodes ) {
		var html = "";
		for ( var node in arguments.nodes ) {
			html &= renderNode( node );
		}
		return html;
	}

	private string function renderNode( required struct node ) {
		switch ( arguments.node.type ) {
			case "text":
				return renderText( arguments.node );
			case "hardBreak":
				return "<br>";
			case "horizontalRule":
				return "<hr>";
			case "heading":
				var level = arguments
					.node
					.attrs
					.level;
				return "<h#level#>#renderNodes( arguments.node.content )#</h#level#>";
			case "orderedList":
				var start = arguments
					.node
					.attrs
					.start;
				// No #...# nested inside an expression inside a string: Adobe ColdFusion may not parse it
				var startAttr = start > 1 ? " start=""" & start & """" : "";
				return "<ol#startAttr#>#renderNodes( arguments.node.content )#</ol>";
			default:
				var tag = variables.CONTAINERS[ arguments.node.type ];
				return "<#tag#>#renderNodes( arguments.node.content )#</#tag#>";
		}
	}

	private string function renderText( required struct node ) {
		var html = variables.markup.esc( arguments.node.text );
		var marks = arguments.node.marks ?: [];
		// The first mark is the outermost
		for ( var i = marks.len(); i >= 1; i-- ) {
			var mark = marks[ i ];
			if ( mark.type == "link" ) {
				var target = ( mark.attrs.target ?: "" ) == "_blank"
					? " target=""_blank"" rel=""noopener noreferrer"""
					: "";
				html = "<a href=""#variables.markup.href( mark.attrs.href )#""#target#>#html#</a>";
			} else {
				var tag = variables.MARKS[ mark.type ];
				html = "<#tag#>#html#</#tag#>";
			}
		}
		return html;
	}

	private string function plainText( required struct doc ) {
		var collected = { "text": "" };
		collectText( arguments.doc.content, collected );
		return collected.text;
	}

	private void function collectText( required array nodes, required struct collected ) {
		for ( var node in arguments.nodes ) {
			if ( node.type == "text" ) {
				arguments.collected.text &= node.text;
			} else if ( node.type == "horizontalRule" ) {
				arguments.collected.text &= "-";
			}
			collectText( node.content ?: [], arguments.collected );
		}
	}

	/**
	 * An attribute of a node or mark from untrusted JSON, or the fallback
	 */
	private any function attr(
		required struct item,
		required string name,
		any fallback = ""
	) {
		if (
			!arguments.item.keyExists( "attrs" ) || !isStruct( arguments.item.attrs ) ||
				!arguments
					.item
					.attrs
					.keyExists( arguments.name )
		) {
			return arguments.fallback;
		}
		var value = arguments.item.attrs[ arguments.name ];
		return isNull( value ) || !isSimpleValue( value ) ? arguments.fallback : value;
	}

	private numeric function clampInt(
		any value,
		numeric min,
		numeric max,
		numeric fallback
	) {
		if ( !isSimpleValue( arguments.value ) || !isNumeric( arguments.value ) ) {
			return arguments.fallback;
		}
		var number = int( arguments.value );
		return number < arguments.min || number > arguments.max ? arguments.fallback : number;
	}

}