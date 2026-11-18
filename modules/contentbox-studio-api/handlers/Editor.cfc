/**
 * Loading and saving content blocks, versions
 */
component extends="BaseHandler" {
	property name="editor" inject="ContentEditor@contentbox-studio";
	this.allowedMethods = {
		"show"    : "GET",
		"save"    : "PUT",
		"versions": "GET",
		"version" : "GET"
	};

	/**
	 * GET /cbstudio/api/content/:contentID: details, parsed blocks and what the author may do
	 */
	function show( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			return prc.response.setErrorMessage( "Content not found", 404 );
		}
		prc.response.setData( variables.editor.load( content, jwtAuth().getUser() ) );
	}

	/**
	 * PUT /cbstudio/api/content/:contentID/blocks with JSON { blocks: [ { type, id, data } ], changelog, baseVersion }
	 * Saves a new version. 422 with { errors } if blocks are invalid, 403 without permission, 409 on a conflict.
	 */
	function save( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			return prc.response.setErrorMessage( "Content not found", 404 );
		}
		if ( !isArray( rc.blocks ?: "" ) ) {
			return prc.response.setErrorMessage( "blocks must be an array", 400 );
		}
		try {
			var result = variables.editor.save(
				content     = content,
				blocks      = rc.blocks,
				changelog   = isSimpleValue( rc.changelog ?: "" ) ? toString( rc.changelog ?: "" ) : "",
				author      = jwtAuth().getUser(),
				baseVersion = isNumeric( rc.baseVersion ?: "" ) ? rc.baseVersion : 0
			);
			prc.response.setData( result );
			if ( !result.saved ) {
				prc
					.response
					.setError( true )
					.setStatusCode( 422 )
					.addMessage( "Some blocks are not valid" );
			}
		} catch (ContentEditor.Forbidden e) {
			prc.response.setErrorMessage( e.message, 403 );
		} catch (ContentEditor.Conflict e) {
			prc.response.setErrorMessage( e.message, 409 );
		}
	}

	/**
	 * GET /cbstudio/api/content/:contentID/versions
	 */
	function versions( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			return prc.response.setErrorMessage( "Content not found", 404 );
		}
		prc.response.setData( variables.editor.versions( content ) );
	}

	/**
	 * GET /cbstudio/api/content/:contentID/versions/:versionID: the blocks of that version
	 */
	function version( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			return prc.response.setErrorMessage( "Content not found", 404 );
		}
		var result = variables.editor.version( content, toString( rc.versionID ?: "" ) );
		if ( isNull( result ) ) {
			return prc.response.setErrorMessage( "Version not found", 404 );
		}
		prc.response.setData( result );
	}

}