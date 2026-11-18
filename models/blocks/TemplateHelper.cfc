/**
 * Available as args.studio in every block's render.cfm. Templates must output field values only through it:
 *
 * #args.studio.esc( args.data.title )#            text (also defuses ContentBox's {{{ }}} and page:[ ] syntax)
 * #args.studio.attr( args.data.alt )#             text inside a double-quoted attribute
 * #args.studio.nl2br( args.data.text )#           multi-line text with <br>
 * #args.studio.richText( args.data.body )#        rich text field as HTML
 * <a#args.studio.linkAttrs( args.data.link )#>    href (and target/rel) of a link field
 * #args.studio.src( args.data.image.src )#        image URL for src=""
 * #args.studio.contentStore( args.data.slug )#    a content store item, rendered by ContentBox on every page view
 */
component singleton {
	property name="markup" inject="Markup@contentbox-studio";

	property name="richTextService" inject="RichText@contentbox-studio";

	string function esc( any text = "" ) {
		return variables.markup.esc( arguments.text );
	}

	string function attr( any text = "" ) {
		return variables.markup.esc( arguments.text );
	}

	string function nl2br( any text = "" ) {
		return variables.markup.nl2br( arguments.text );
	}

	string function richText( any doc = "" ) {
		return variables.richTextService.toHTML( arguments.doc );
	}

	string function src( any source = "" ) {
		return variables.markup.esc( variables.markup.safeImageUrl( arguments.source ) );
	}

	/**
	 * ` href="..."` plus ` target="_blank" rel="noopener noreferrer"` for new-window links; "" without a safe href
	 *
	 * @link A link field value { href, target }
	 */
	string function linkAttrs( any link = {} ) {
		if ( isNull( arguments.link ) || !isStruct( arguments.link ) ) {
			return "";
		}
		var href = variables.markup.href( arguments.link.href ?: "" );
		if ( !len( href ) ) {
			return "";
		}
		var target = ( arguments.link.target ?: "" ) == "_blank"
			? " target=""_blank"" rel=""noopener noreferrer"""
			: "";
		return " href=""#href#""#target#";
	}

	/**
	 * ContentBox's ContentStore widget, so the item stays live: ContentBox renders it whenever the page renders
	 */
	string function contentStore( any slug = "" ) {
		if (
			isNull( arguments.slug ) || !isSimpleValue( arguments.slug ) ||
				!reFind( "^[A-Za-z0-9_/-]+$", arguments.slug )
		) {
			return "";
		}
		return "{{{ContentStore slug=""#arguments.slug#""}}}";
	}

}