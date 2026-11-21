/**
 * Parsing and comparing HTML for the conversion tool, with jsoup (ContentBox ships it with cbmarkdown; cbjavaloader
 * loads it).
 *
 * Two comparisons: canonical() for "the same markup" (what a browser shows the same counts as the same), and
 * missingContent() for "nothing lost" (every text, link and image of the old HTML is in the new one).
 */
component singleton {
	property name="wirebox" inject="wirebox";

	// Elements whose leading and trailing whitespace the browser does not show
	variables.BLOCKS = "address,article,aside,blockquote,dd,div,dl,dt,figcaption,figure,footer,h1,h2,h3,h4,h5,h6,header,li,main,nav,ol,p,section,td,th,ul";
	variables.SPACE = "[ \t\r\n]+";

	/**
	 * The body element of an HTML fragment
	 */
	function parse( required string html ) {
		return jsoup().parseBodyFragment( arguments.html ).body();
	}

	/**
	 * Element and non-blank text nodes of an element, in order (comments are dropped)
	 */
	array function children( required element ) {
		var result = [];
		for ( var node in nodesOf( arguments.element ) ) {
			var name = node.nodeName();
			if ( name == "##text" ) {
				if ( len( trim( node.getWholeText() ) ) ) {
					result.append( node );
				}
			} else if ( name != "##comment" ) {
				result.append( node );
			}
		}
		return result;
	}

	/**
	 * All child nodes of an element as a CFML array (jsoup returns a Java list)
	 */
	array function nodesOf( required element ) {
		var result = [];
		var nodes = arguments.element.childNodes();
		for ( var i = 0; i < nodes.size(); i++ ) {
			result.append( nodes.get( javacast( "int", i ) ) );
		}
		return result;
	}

	/**
	 * Elements found by a CSS selector inside an element, as a CFML array
	 */
	array function selectAll( required element, required string selector ) {
		var result = [];
		var found = arguments.element.select( arguments.selector );
		for ( var i = 0; i < found.size(); i++ ) {
			result.append( found.get( javacast( "int", i ) ) );
		}
		return result;
	}

	boolean function isText( required node ) {
		return arguments.node.nodeName() == "##text";
	}

	/**
	 * Canonical form for comparing markup: one line per element, attributes and class names sorted, whitespace
	 * collapsed, entities decoded, comments and blank text dropped. Only differences the browser does not show are
	 * ignored: whitespace next to <br> or at the edges of a block element, and rel="noopener" on links that do not
	 * open a new window.
	 */
	string function canonical( required string html ) {
		var collected = { "lines": [] };
		canonicalNode( parse( arguments.html ), 0, collected );
		return collected.lines.toList( chr( 10 ) );
	}

	/**
	 * Texts, link targets and image sources of a fragment. Texts are the text nodes and image alt texts, whitespace
	 * collapsed (non-breaking spaces count as spaces, soft hyphens are dropped).
	 *
	 * @return { texts: [], links: [], images: [] }
	 */
	struct function contentOf( required string html ) {
		var found = {
			"texts" : [],
			"links" : [],
			"images": []
		};
		collectContent( parse( arguments.html ), found );
		return found;
	}

	/**
	 * What of the old HTML is not in the new: each text must occur in the new HTML's text, each link target and image
	 * source among its links and images. What the new HTML adds (labels of the theme, decoration) does not count.
	 *
	 * @return [ "Text: ...", "Link: ...", "Image: ..." ], empty if nothing is missing
	 */
	array function missingContent( required string original, required string converted ) {
		var before = contentOf( arguments.original );
		var after = contentOf( arguments.converted );
		var allText = " " & after.texts.toList( " " ) & " ";
		var missing = [];
		for ( var text in before.texts ) {
			if ( !find( text, allText ) ) {
				missing.append( "Text: " & text );
			}
		}
		for ( var link in before.links ) {
			if ( !after.links.find( link ) ) {
				missing.append( "Link: " & link );
			}
		}
		for ( var image in before.images ) {
			if ( !after.images.find( image ) ) {
				missing.append( "Image: " & image );
			}
		}
		return missing;
	}

	/********************************* PRIVATE *********************************/

	private function jsoup() {
		if ( !variables.keyExists( "jsoupClass" ) ) {
			variables.jsoupClass = variables.wirebox.getInstance( "loader@cbjavaloader" ).create( "org.jsoup.Jsoup" );
		}
		return variables.jsoupClass;
	}

	private void function canonicalNode( required node, numeric depth, required struct collected ) {
		var indent = repeatString( "  ", arguments.depth );
		var isBlock = listFindNoCase( variables.BLOCKS, arguments.node.nodeName() ) > 0;
		for ( var child in nodesOf( arguments.node ) ) {
			var name = child.nodeName();
			if ( name == "##comment" ) {
				continue;
			}
			if ( name == "##text" ) {
				var text = reReplace( child.getWholeText(), variables.SPACE, " ", "all" );
				if ( !len( trim( text ) ) ) {
					continue;
				}
				var previous = child.previousSibling();
				var next = child.nextSibling();
				if ( ( isNull( previous ) && isBlock ) || ( !isNull( previous ) && previous.nodeName() == "br" ) ) {
					text = reReplace( text, "^ ", "" );
				}
				if ( ( isNull( next ) && isBlock ) || ( !isNull( next ) && next.nodeName() == "br" ) ) {
					text = reReplace( text, " $", "" );
				}
				arguments.collected.lines.append( indent & """" & text & """" );
				continue;
			}
			var attrs = [];
			var attributes = child.attributes().asList();
			for ( var i = 0; i < attributes.size(); i++ ) {
				var attribute = attributes.get( javacast( "int", i ) );
				var key = attribute.getKey();
				var value = attribute.getValue();
				// rel="noopener" only matters for links that open a new window
				if ( name == "a" && key == "rel" && value == "noopener" && !child.hasAttr( "target" ) ) {
					continue;
				}
				if ( key == "class" ) {
					value = listSort( reReplace( trim( value ), variables.SPACE, " ", "all" ), "text", "asc", " " );
				}
				attrs.append( key & "=""" & value & """" );
			}
			attrs.sort( "text" );
			arguments.collected.lines.append( indent & "<" & name & ( attrs.len() ? " " & attrs.toList( " " ) : "" ) & ">" );
			canonicalNode( child, arguments.depth + 1, arguments.collected );
		}
	}

	private void function collectContent( required node, required struct found ) {
		for ( var child in nodesOf( arguments.node ) ) {
			var name = child.nodeName();
			if ( name == "##text" ) {
				var text = plain( child.getWholeText() );
				if ( len( text ) ) {
					arguments.found.texts.append( text );
				}
				continue;
			}
			if ( name == "##comment" || name == "##data" ) {
				continue;
			}
			if ( name == "a" && len( trim( child.attr( "href" ) ) ) ) {
				arguments.found.links.append( trim( child.attr( "href" ) ) );
			}
			if ( name == "img" ) {
				if ( len( trim( child.attr( "src" ) ) ) ) {
					arguments.found.images.append( trim( child.attr( "src" ) ) );
				}
				var alt = plain( child.attr( "alt" ) );
				if ( len( alt ) ) {
					arguments.found.texts.append( alt );
				}
			}
			collectContent( child, arguments.found );
		}
	}

	private string function plain( required string text ) {
		var result = replace( arguments.text, chr( 160 ), " ", "all" );
		result = replace( result, chr( 173 ), "", "all" );
		return trim( reReplace( result, variables.SPACE, " ", "all" ) );
	}

}
