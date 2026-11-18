/**
 * Public output of block content:
 * - removes Studio's block markers from rendered content, so the page only contains the block HTML (the stored body
 * keeps them; without Studio they would simply stay as HTML comments)
 * - links the core blocks' base styles (includes/blocks.css) on pages with blocks, unless coreBlockStyles is off
 */
component {
	property name="format" inject="BlockFormat@contentbox-studio";

	property name="studioModule" inject="coldbox:moduleConfig:contentbox-studio";

	property name="settings" inject="coldbox:moduleSettings:contentbox-studio";

	void function cb_onContentRendering( event, data ) {
		stripMarkers( arguments.event, arguments.data.builder );
	}

	void function cb_onContentStoreRendering( event, data ) {
		stripMarkers( arguments.event, arguments.data.builder );
	}

	void function cbui_beforeHeadEnd( event, data, buffer ) {
		if ( !variables.settings.coreBlockStyles || !hasBlocks( arguments.event ) ) {
			return;
		}
		var href = arguments.event.getModuleRoot(
			"contentbox-studio"
		) & "/includes/blocks.css?v=" & variables.studioModule.version;
		arguments.buffer.append( "<link rel=""stylesheet"" href=""#href#"">#chr( 10 )#" );
	}

	private void function stripMarkers( event, builder ) {
		if ( isNull( arguments.builder ) ) {
			return;
		}
		var body = arguments.builder.toString();
		if ( !find( "cb:block", body ) ) {
			return;
		}
		arguments.event.setPrivateValue( "cbstudioHasBlocks", true );
		arguments.builder.setLength( 0 );
		arguments.builder.append( variables.format.stripMarkers( body ) );
	}

	/**
	 * Blocks rendered in this request, or a page/entry with blocks (its rendering may come from ContentBox's cache)
	 */
	private boolean function hasBlocks( event ) {
		if ( arguments.event.getPrivateValue( "cbstudioHasBlocks", false ) ) {
			return true;
		}
		for ( var key in [ "page", "entry" ] ) {
			var content = arguments.event.getPrivateValue( key, "" );
			if ( isObject( content ) && content.isLoaded() && find( "cb:block", content.getContent() ) ) {
				return true;
			}
		}
		return false;
	}

}