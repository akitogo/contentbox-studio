/**
 * Removes Studio's block markers from rendered content, so the public page only contains the block HTML.
 * The stored body keeps them; without Studio they would simply stay as HTML comments.
 */
component {
	property name="format" inject="BlockFormat@contentbox-studio";

	void function cb_onContentRendering( event, data ) {
		stripMarkers( arguments.data.builder );
	}

	void function cb_onContentStoreRendering( event, data ) {
		stripMarkers( arguments.data.builder );
	}

	private void function stripMarkers( builder ) {
		if ( isNull( arguments.builder ) ) {
			return;
		}
		var body = arguments.builder.toString();
		if ( !find( "cb:block", body ) ) {
			return;
		}
		arguments.builder.setLength( 0 );
		arguments.builder.append( variables.format.stripMarkers( body ) );
	}

}