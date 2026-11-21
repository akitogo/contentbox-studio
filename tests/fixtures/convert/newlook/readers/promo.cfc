/**
 * Fixture code reader: old promo boxes become banners
 */
component {

	function read( required element, required read ) {
		if ( !arguments.element.hasClass( "promo" ) ) {
			return;
		}
		var button = arguments.element.selectFirst( "a" );
		return {
			"title"    : arguments.read.text( arguments.element.selectFirst( ".promo-title" ) ),
			"text"     : arguments.read.lines( arguments.element.selectFirst( ".promo-text" ) ),
			"tone"     : "dark",
			"link"     : arguments.read.link( button ),
			"linkLabel": arguments.read.text( button )
		};
	}

}
