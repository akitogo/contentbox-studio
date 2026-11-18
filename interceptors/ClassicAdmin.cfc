/**
 * Protects block pages from the classic admin editor.
 *
 * The block data lives in the body next to the rendered HTML. Editing that HTML in the classic editor would be
 * overwritten by the next Studio save, and CKEditor reformats HTML even without edits. So for content with blocks:
 *
 * - the editor shows a notice with a link to Studio and the body editor is read-only
 * - on save, the body of the previous version is kept, whatever the editor posted; all other settings (title,
 * slug, SEO, categories, publishing) still save normally
 */
component {
	property name="format" inject="BlockFormat@contentbox-studio";

	property name="markup" inject="Markup@contentbox-studio";

	property name="log" inject="logbox:logger:{this}";

	/**
	 * Notice and read-only body in the classic content editor
	 */
	void function cbadmin_contentEditorFooter( event, data, buffer ) {
		var content = arguments.event.getPrivateValue( "oContent", "" );
		if ( !isObject( content ) || !content.isLoaded() || !variables.format.hasBlocks( content.getContent() ) ) {
			return;
		}
		// Escaped for the href attribute (encodeForHTMLAttribute would also encode every "/")
		var studioLink = variables.markup.esc(
			arguments.event.buildLink( "cbstudio/content/#content.getContentID()#" )
		);
		savecontent variable="local.html" {
			include template="/contentbox-studio/views/classicAdmin/editorNotice.cfm";
		}
		arguments.buffer.append( html );
	}

	void function cbadmin_prePageSave( event, data ) {
		keepBlockBody( arguments.data );
	}

	void function cbadmin_preEntrySave( event, data ) {
		keepBlockBody( arguments.data );
	}

	void function cbadmin_preContentStoreSave( event, data ) {
		keepBlockBody( arguments.data );
	}

	/**
	 * The admin has already added the posted body as the new active version; put the previous body back into it
	 * if that one had blocks
	 */
	private void function keepBlockBody( required struct data ) {
		if ( ( arguments.data.isNew ?: true ) || !isObject( arguments.data.content ?: "" ) ) {
			return;
		}
		var content = arguments.data.content;
		var versions = content.getContentVersions() ?: [];
		var active = versions.filter( ( version ) => version.getIsActive() );
		var previous = versions.filter( ( version ) => !version.getIsActive() );
		if ( !active.len() || !previous.len() ) {
			return;
		}
		previous.sort( ( a, b ) => b.getVersion() - a.getVersion() );

		var before = previous[ 1 ].getContent();
		if ( !variables.format.hasBlocks( before ) || compare( before, active[ 1 ].getContent() ) == 0 ) {
			return;
		}
		active[ 1 ].setContent( before );
		variables.log.info(
			"ContentBox Studio kept the block body of [#content.getSlug()#]: block content is edited in Studio, not in the classic editor"
		);
	}

}