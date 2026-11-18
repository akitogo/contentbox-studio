/**
 * hreflang links for pages and blog entries in a translation group (models/tree/Translations.cfc):
 * <link rel="alternate" hreflang="de" href="..."> for every member with a language, including the page itself.
 */
component {
	property name="translations" inject="Translations@contentbox-studio";

	property name="markup" inject="Markup@contentbox-studio";

	property name="log" inject="logbox:logger:{this}";

	void function cbui_beforeHeadEnd( event, data, buffer ) {
		var content = arguments.event.getPrivateValue( "page", "" );
		if ( !isObject( content ) ) {
			content = arguments.event.getPrivateValue( "entry", "" );
		}
		if ( !isObject( content ) || !content.isLoaded() ) {
			return;
		}
		try {
			var group = variables.translations.forContent( content );
			var links = group.members.filter( ( member ) => len( member.language ) );
			if ( links.len() < 2 ) {
				return;
			}
			for ( var member in links ) {
				arguments.buffer.append(
					"<link rel=""alternate"" hreflang=""#variables.markup.esc(
						member.language
					)#"" href=""#variables.markup.esc( member.url )#"">#chr( 10 )#"
				);
			}
		} catch (any e) {
			// Never break the public page for hreflang links
			variables.log.error(
				"ContentBox Studio: hreflang links failed for #content.getSlug()#: #e.message#"
			);
		}
	}

}