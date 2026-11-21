/**
 * Reads block data from old HTML for the conversion tool. A profile rule only says where a field's value is (a CSS
 * selector); how it is read follows from the field's type in the block's block.json:
 *
 * | Type | Read as |
 * |---|---|
 * | text, contentStore | the element's text (no markup inside) or an attribute |
 * | textarea | text with <br> as line breaks |
 * | richtext | paragraphs, headings, lists, quotes, rules, bold/italic/underline/strike/code/sub/sup and links |
 * | number | the text or attribute as a number |
 * | boolean | whether the selector finds an element, or a class map ({ "classes": { "wide": true } }) |
 * | select | a class map ({ "classes": { "c75": "sand" } }), an attribute or the text; must be one of the options |
 * | link | href and target of an <a> |
 * | image / images | src and alt of an <img> (all matches for images) |
 * | list | { "each": selector of the items, "fields": { ... } }, read per item like the block |
 * | html | the element's inner HTML as it is |
 *
 * A spec is a selector string ("p.lead"; "&" or "" is the section itself; "img @alt" or "@data-id" reads an
 * attribute) or a struct { select, attr, classes, each, fields, value, ignore }; "value" sets a fixed value, "ignore"
 * (a selector) leaves out elements the template outputs itself, like an icon in a button. A missing element gives the
 * field's empty value. Markup a field cannot hold throws Convert.Unconvertible, so the section stays HTML
 * instead of losing something.
 *
 * The public helpers (text, lines, richText, richTextOf, link, image, images, classFrom, select, selectAll,
 * unconvertible) are also what code readers of a profile get; text, lines and richText take an optional ignore
 * selector.
 */
component singleton {
	property name="html" inject="HtmlTree@contentbox-studio";

	variables.SPACE = "[ \t\r\n]+";
	variables.MARKS = {
		"strong": "bold",
		"b"     : "bold",
		"em"    : "italic",
		"i"     : "italic",
		"u"     : "underline",
		"s"     : "strike",
		"strike": "strike",
		"del"   : "strike",
		"code"  : "code",
		"sub"   : "subscript",
		"sup"   : "superscript"
	};
	variables.TEXTBLOCKS = "p,h1,h2,h3,h4,h5,h6";
	variables.CONTAINERS = "ul,ol,blockquote,hr";

	/**
	 * Block data from an element
	 *
	 * @fields Field definitions of the block type (block.json)
	 * @specs  { fieldName: spec }; fields without a spec are left out and get their default
	 */
	struct function readFields( required element, required array fields, required struct specs ) {
		var data = {};
		for ( var field in arguments.fields ) {
			if ( arguments.specs.keyExists( field.name ) ) {
				data[ field.name ] = readField( arguments.element, field, arguments.specs[ field.name ] );
			}
		}
		return data;
	}

	/**
	 * One field's value from an element
	 */
	any function readField( required element, required struct field, required any spec ) {
		var rule = normalizeSpec( arguments.spec );
		if ( rule.keyExists( "value" ) ) {
			return rule.value;
		}
		var type = arguments.field.type;
		if ( type == "images" ) {
			return images( selectAll( arguments.element, rule.select ) );
		}
		if ( type == "list" ) {
			var items = [];
			var subFields = arguments.field.fields ?: [];
			var subSpecs = isStruct( rule.fields ?: "" ) ? rule.fields : {};
			for ( var item in selectAll( arguments.element, rule.each ?: rule.select ) ) {
				items.append( readFields( item, subFields, subSpecs ) );
			}
			return items;
		}

		var target = select( arguments.element, rule.select );
		if ( isNull( target ) ) {
			return emptyValue( type );
		}
		// Elements the template outputs itself (e.g. an icon in a button) are left out
		target = without( target, rule.ignore );
		switch ( type ) {
			case "text":
			case "contentStore":
				return len( rule.attr ) ? trim( target.attr( rule.attr ) ) : text( target );
			case "textarea":
				return len( rule.attr ) ? trim( target.attr( rule.attr ) ) : lines( target );
			case "richtext":
				return richText( target );
			case "number":
				var number = len( rule.attr ) ? trim( target.attr( rule.attr ) ) : text( target );
				if ( !len( number ) ) {
					return "";
				}
				if ( !isNumeric( number ) ) {
					unconvertible( "#arguments.field.name#: '#number#' is not a number" );
				}
				return val( number );
			case "boolean":
				if ( isStruct( rule.classes ?: "" ) ) {
					var flag = classFrom( target, rule.classes );
					return isBoolean( flag ) && flag;
				}
				return true;
			case "select":
				var value = "";
				if ( isStruct( rule.classes ?: "" ) ) {
					value = classFrom( target, rule.classes );
				} else if ( len( rule.attr ) ) {
					value = trim( target.attr( rule.attr ) );
				} else {
					value = text( target );
				}
				if ( len( value ) && !isOption( arguments.field, value ) ) {
					unconvertible( "#arguments.field.name#: '#value#' is not one of the options" );
				}
				return value;
			case "link":
				return link( target );
			case "image":
				return image( target );
			case "html":
				return target.html();
		}
		unconvertible( "#arguments.field.name#: fields of type #type# cannot be read" );
	}

	/**
	 * The first element matching a selector inside an element; the element itself for "" or "&"
	 */
	function select( required element, string selector = "" ) {
		if ( !len( arguments.selector ) || arguments.selector == "&" ) {
			return arguments.element;
		}
		try {
			return arguments.element.selectFirst( arguments.selector );
		} catch ( any e ) {
			invalidSelector( arguments.selector, e );
		}
	}

	/**
	 * All elements matching a selector inside an element; [ element ] for "" or "&"
	 */
	array function selectAll( required element, string selector = "" ) {
		if ( !len( arguments.selector ) || arguments.selector == "&" ) {
			return [ arguments.element ];
		}
		try {
			return variables.html.selectAll( arguments.element, arguments.selector );
		} catch ( any e ) {
			invalidSelector( arguments.selector, e );
		}
	}

	/**
	 * Text of an element without markup inside, whitespace collapsed ("" for none)
	 *
	 * @ignore Selector of elements to leave out (e.g. "svg" for an icon the template outputs itself)
	 */
	string function text( element, string ignore = "" ) {
		if ( isNull( arguments.element ) ) {
			return "";
		}
		var value = "";
		for ( var node in variables.html.nodesOf( without( arguments.element, arguments.ignore ) ) ) {
			var name = node.nodeName();
			if ( name == "##text" ) {
				value &= node.getWholeText();
			} else if ( name != "##comment" ) {
				unconvertible( "markup in a one-line text: <#name#>" );
			}
		}
		return trim( reReplace( value, variables.SPACE, " ", "all" ) );
	}

	/**
	 * Text with <br> as line breaks, for textarea fields; other markup is not convertible
	 */
	string function lines( element, string ignore = "" ) {
		if ( isNull( arguments.element ) ) {
			return "";
		}
		var value = "";
		for ( var node in variables.html.nodesOf( without( arguments.element, arguments.ignore ) ) ) {
			var name = node.nodeName();
			if ( name == "##text" ) {
				value &= reReplace( node.getWholeText(), variables.SPACE, " ", "all" );
			} else if ( name == "br" ) {
				value &= chr( 10 );
			} else if ( name != "##comment" ) {
				unconvertible( "markup in a text: <#name#>" );
			}
		}
		var result = [];
		for ( var line in listToArray( value, chr( 10 ), true ) ) {
			result.append( trim( line ) );
		}
		return trim( result.toList( chr( 10 ) ) );
	}

	/**
	 * Rich text document (ProseMirror JSON, like the editor's) from the content of an element
	 */
	struct function richText( element, string ignore = "" ) {
		var doc = { "type": "doc", "content": [] };
		if ( !isNull( arguments.element ) ) {
			doc.content = blocksOf( variables.html.nodesOf( without( arguments.element, arguments.ignore ) ) );
		}
		return doc;
	}

	/**
	 * Rich text document from several nodes, e.g. the paragraphs of a column without its heading
	 */
	struct function richTextOf( required array nodes ) {
		return { "type": "doc", "content": blocksOf( arguments.nodes ) };
	}

	/**
	 * { href, target } of a link
	 */
	struct function link( element ) {
		if ( isNull( arguments.element ) ) {
			return { "href": "", "target": "" };
		}
		if ( !arguments.element.hasAttr( "href" ) ) {
			unconvertible( "not a link: <#arguments.element.nodeName()#>" );
		}
		return {
			"href"  : trim( arguments.element.attr( "href" ) ),
			"target": arguments.element.attr( "target" ) == "_blank" ? "_blank" : ""
		};
	}

	/**
	 * { src, alt } of an image, plus width and height if it has them
	 */
	struct function image( element ) {
		if ( isNull( arguments.element ) ) {
			return { "src": "", "alt": "" };
		}
		if ( !arguments.element.hasAttr( "src" ) ) {
			unconvertible( "not an image: <#arguments.element.nodeName()#>" );
		}
		var result = {
			"src": trim( arguments.element.attr( "src" ) ),
			"alt": trim( arguments.element.attr( "alt" ) )
		};
		for ( var key in [ "width", "height" ] ) {
			if ( isNumeric( arguments.element.attr( key ) ) ) {
				result[ key ] = val( arguments.element.attr( key ) );
			}
		}
		return result;
	}

	array function images( required array elements ) {
		var result = [];
		for ( var element in arguments.elements ) {
			result.append( image( element ) );
		}
		return result;
	}

	/**
	 * The value for the first class of the element found in the map, "" if none
	 */
	any function classFrom( element, required struct map ) {
		if ( isNull( arguments.element ) ) {
			return "";
		}
		for ( var className in listToArray( arguments.element.className(), " " ) ) {
			if ( arguments.map.keyExists( className ) ) {
				return arguments.map[ className ];
			}
		}
		return "";
	}

	/**
	 * Stop reading this section: it stays an HTML block, with the message in the report
	 */
	void function unconvertible( required string message ) {
		throw( type = "Convert.Unconvertible", message = arguments.message );
	}

	/********************************* PRIVATE *********************************/

	/**
	 * { select, attr, ... } from a selector string or struct
	 */
	private struct function normalizeSpec( required any spec ) {
		var rule = {};
		if ( isSimpleValue( arguments.spec ) ) {
			rule = { "select": trim( arguments.spec ) };
		} else if ( isStruct( arguments.spec ) ) {
			rule = duplicate( arguments.spec );
			rule[ "select" ] = trim( rule.select ?: "" );
		} else {
			throw( type = "Convert.InvalidProfile", message = "A field spec must be a selector or an object" );
		}
		rule[ "attr" ] = isSimpleValue( rule.attr ?: "" ) ? trim( rule.attr ?: "" ) : "";
		rule[ "ignore" ] = isSimpleValue( rule.ignore ?: "" ) ? trim( rule.ignore ?: "" ) : "";
		// "img @alt" or "@data-id": an attribute of the selected element
		var at = find( "@", rule.select );
		if ( at ) {
			rule.attr = trim( mid( rule.select, at + 1, len( rule.select ) ) );
			rule.select = at > 1 ? trim( left( rule.select, at - 1 ) ) : "";
		}
		return rule;
	}

	/**
	 * A copy of the element without the elements matching a selector (the element itself if there is none)
	 */
	private function without( required element, string ignore = "" ) {
		if ( !len( arguments.ignore ) ) {
			return arguments.element;
		}
		var copy = arguments.element.clone();
		try {
			copy.select( arguments.ignore ).remove();
		} catch ( any e ) {
			invalidSelector( arguments.ignore, e );
		}
		return copy;
	}

	private any function emptyValue( required string type ) {
		switch ( arguments.type ) {
			case "richtext":
				return { "type": "doc", "content": [] };
			case "boolean":
				return false;
			case "link":
				return { "href": "", "target": "" };
			case "image":
				return { "src": "", "alt": "" };
		}
		return "";
	}

	private boolean function isOption( required struct field, required string value ) {
		for ( var option in arguments.field.options ?: [] ) {
			var optionValue = isStruct( option ) ? ( option.value ?: "" ) : option;
			if ( toString( optionValue ) == arguments.value ) {
				return true;
			}
		}
		return false;
	}

	/**
	 * Rich text blocks from nodes: paragraphs, headings, lists, quotes and rules; loose inline content becomes a
	 * paragraph
	 */
	private array function blocksOf( required array nodes ) {
		var result = [];
		var run = [];
		for ( var node in arguments.nodes ) {
			var name = lCase( node.nodeName() );
			if ( name == "##comment" ) {
				continue;
			}
			if ( listFind( variables.TEXTBLOCKS, name ) || listFind( variables.CONTAINERS, name ) || name == "li" ) {
				if ( run.len() ) {
					result.append( paragraphOf( run ), true );
					run = [];
				}
				result.append( blockOf( node, name ) );
			} else {
				run.append( node );
			}
		}
		if ( run.len() ) {
			result.append( paragraphOf( run ), true );
		}
		return result;
	}

	/**
	 * [ paragraph ] from inline nodes, [] if they are only whitespace
	 */
	private array function paragraphOf( required array nodes ) {
		var content = textblockContent( arguments.nodes );
		return content.len() ? [ { "type": "paragraph", "content": content } ] : [];
	}

	private struct function blockOf( required node, required string name ) {
		switch ( arguments.name ) {
			case "p":
				return {
					"type"   : "paragraph",
					"content": textblockContent( variables.html.nodesOf( arguments.node ) )
				};
			case "ul":
			case "ol":
				var items = [];
				for ( var child in variables.html.children( arguments.node ) ) {
					if ( variables.html.isText( child ) || lCase( child.nodeName() ) != "li" ) {
						unconvertible( "a list with <#child.nodeName()#> in it" );
					}
					items.append( {
						"type"   : "listItem",
						"content": blocksOf( variables.html.nodesOf( child ) )
					} );
				}
				if ( arguments.name == "ul" ) {
					return { "type": "bulletList", "content": items };
				}
				return {
					"type"   : "orderedList",
					"attrs"  : { "start": isNumeric( arguments.node.attr( "start" ) ) ? val( arguments.node.attr( "start" ) ) : 1 },
					"content": items
				};
			case "blockquote":
				return {
					"type"   : "blockquote",
					"content": blocksOf( variables.html.nodesOf( arguments.node ) )
				};
			case "hr":
				return { "type": "horizontalRule" };
			case "li":
				unconvertible( "a list item outside a list" );
		}
		// h1-h6
		return {
			"type"   : "heading",
			"attrs"  : { "level": val( right( arguments.name, 1 ) ) },
			"content": textblockContent( variables.html.nodesOf( arguments.node ) )
		};
	}

	/**
	 * Inline content of a paragraph or heading, without whitespace at its edges
	 */
	private array function textblockContent( required array nodes ) {
		var content = inlineOf( arguments.nodes, [] );
		if ( content.len() && content[ 1 ].type == "text" ) {
			content[ 1 ].text = reReplace( content[ 1 ].text, "^ ", "" );
		}
		if ( content.len() && content[ content.len() ].type == "text" ) {
			content[ content.len() ].text = reReplace( content[ content.len() ].text, " $", "" );
		}
		return content.filter( ( node ) => node.type != "text" || len( node.text ) );
	}

	private array function inlineOf( required array nodes, required array marks ) {
		var result = [];
		for ( var node in arguments.nodes ) {
			var name = lCase( node.nodeName() );
			if ( name == "##comment" ) {
				continue;
			}
			if ( name == "##text" ) {
				var text = reReplace( node.getWholeText(), variables.SPACE, " ", "all" );
				if ( len( text ) ) {
					var item = { "type": "text", "text": text };
					if ( arguments.marks.len() ) {
						item[ "marks" ] = duplicate( arguments.marks );
					}
					result.append( item );
				}
			} else if ( name == "br" ) {
				result.append( { "type": "hardBreak" } );
			} else if ( name == "a" ) {
				var attrs = { "href": trim( node.attr( "href" ) ) };
				if ( node.attr( "target" ) == "_blank" ) {
					attrs[ "target" ] = "_blank";
				}
				result.append(
					inlineOf( variables.html.nodesOf( node ), withMark( arguments.marks, { "type": "link", "attrs": attrs } ) ),
					true
				);
			} else if ( variables.MARKS.keyExists( name ) ) {
				result.append(
					inlineOf( variables.html.nodesOf( node ), withMark( arguments.marks, { "type": variables.MARKS[ name ] } ) ),
					true
				);
			} else if ( name == "span" && !node.attributes().size() ) {
				result.append( inlineOf( variables.html.nodesOf( node ), arguments.marks ), true );
			} else {
				unconvertible( "rich text with <#name#>" );
			}
		}
		return result;
	}

	/**
	 * A new marks array with one more mark (append() changes the array it is called on)
	 */
	private array function withMark( required array marks, required struct mark ) {
		var result = duplicate( arguments.marks );
		result.append( arguments.mark );
		return result;
	}

	private void function invalidSelector( required string selector, required any error ) {
		throw(
			type    = "Convert.InvalidProfile",
			message = "Invalid selector '#arguments.selector#': #arguments.error.message#"
		);
	}

}
