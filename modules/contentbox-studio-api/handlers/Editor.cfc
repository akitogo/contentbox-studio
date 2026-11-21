/**
 * Loading and saving content blocks, versions
 */
component extends="BaseHandler" {
	property name="editor" inject="ContentEditor@contentbox-studio";

	property name="canvasHeader" inject="CanvasHeader@contentbox-studio";
	this.allowedMethods = {
		"show"    : "GET",
		"save"    : "PUT",
		"versions": "GET",
		"version" : "GET",
		"status"  : "PUT",
		"header"  : "POST",
		"template": "POST"
	};

	/**
	 * GET /cbstudio/api/content/:contentID: details, parsed blocks and what the author may do
	 */
	function show( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		prc.response.setData( variables.editor.load( content, jwtAuth().getUser() ) );
	}

	/**
	 * PUT /cbstudio/api/content/:contentID/blocks with JSON { blocks: [ { type, id, data } ], changelog, baseVersion,
	 * and optionally title, seo: { title, description, keywords }, language, showInMenu, entry: { publishedDate, expireDate, categories,
	 * excerpt, featuredImage, allowComments } (see ContentEditor.save()) }
	 * Saves a new version if the blocks changed. 422 with { errors } if blocks are invalid, 400 for invalid settings,
	 * 403 without permission, 409 on a conflict.
	 */
	function save( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		if ( !isArray( rc.blocks ?: "" ) ) {
			prc.response.setErrorMessage( "blocks must be an array", 400 );
			return;
		}
		var args = {
			content    : content,
			blocks     : rc.blocks,
			changelog  : isSimpleValue( rc.changelog ?: "" ) ? toString( rc.changelog ?: "" ) : "",
			author     : jwtAuth().getUser(),
			baseVersion: isNumeric( rc.baseVersion ?: "" ) ? rc.baseVersion : 0
		};
		// Optional parts: left unchanged when not sent
		if ( isStruct( rc.seo ?: "" ) ) {
			args.seo = rc.seo;
		}
		if ( isSimpleValue( rc.language ?: [] ) ) {
			args.language = toString( rc.language );
		}
		if ( isStruct( rc.entry ?: "" ) ) {
			args.entry = rc.entry;
		}
		if ( rc.keyExists( "title" ) && isSimpleValue( rc.title ) ) {
			args.title = toString( rc.title );
		}
		// Not "rc.showInMenu ?: ...": Adobe ColdFusion's Elvis operator also replaces false
		if ( rc.keyExists( "showInMenu" ) ) {
			if ( !isBoolean( rc.showInMenu ) ) {
				prc.response.setErrorMessage( "showInMenu must be true or false", 400 );
				return;
			}
			args.showInMenu = rc.showInMenu;
		}
		try {
			var result = variables.editor.save( argumentCollection = args );
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
		} catch (ContentEditor.Invalid e) {
			prc.response.setErrorMessage( e.message, 400 );
		}
	}

	/**
	 * GET /cbstudio/api/content/:contentID/versions
	 */
	function versions( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		prc.response.setData( variables.editor.versions( content ) );
	}

	/**
	 * GET /cbstudio/api/content/:contentID/versions/:versionID: the blocks of that version
	 */
	function version( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		var result = variables.editor.version( content, toString( rc.versionID ?: "" ) );
		if ( isNull( result ) ) {
			prc.response.setErrorMessage( "Version not found", 404 );
			return;
		}
		prc.response.setData( result );
	}

	/**
	 * PUT /cbstudio/api/content/:contentID/status with JSON { isPublished }
	 */
	function status( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		// Not "rc.isPublished ?: ...": Adobe ColdFusion's Elvis operator also replaces false (unpublishing)
		if ( !rc.keyExists( "isPublished" ) || !isBoolean( rc.isPublished ) ) {
			prc.response.setErrorMessage( "isPublished must be true or false", 400 );
			return;
		}
		try {
			prc.response.setData(
				variables.editor.setPublished(
					content,
					rc.isPublished,
					jwtAuth().getUser()
				)
			);
		} catch (ContentEditor.Forbidden e) {
			prc.response.setErrorMessage( e.message, 403 );
		}
	}

	/**
	 * POST /cbstudio/api/content/:contentID/header with JSON { title, publishedDate, categories: [ names ],
	 * featuredImage } (each optional: the values being edited): the header of a blog entry in the editor canvas, as
	 * the theme shows it, see CanvasHeader. Returns { html } ("" for pages and content store items).
	 */
	function header( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		var values = {};
		for ( var key in [ "title", "publishedDate", "featuredImage" ] ) {
			if ( rc.keyExists( key ) && isSimpleValue( rc[ key ] ) ) {
				values[ key ] = toString( rc[ key ] );
			}
		}
		if ( isArray( rc.categories ?: "" ) ) {
			values[ "categories" ] = rc.categories;
		}
		prc.response.setData( variables.canvasHeader.render( content, values ) );
	}

	/**
	 * POST /cbstudio/api/content/:contentID/template with JSON { name, description, isGlobal }: the saved body as a
	 * content template (block preset for new content of its type; isGlobal: the default one)
	 */
	function template( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		try {
			prc
				.response
				.setData(
					variables.editor.saveAsTemplate(
						content     = content,
						name        = toString( rc.name ?: "" ),
						description = toString( rc.description ?: "" ),
						author      = jwtAuth().getUser(),
						isGlobal    = rc.keyExists( "isGlobal" ) && isBoolean( rc.isGlobal ) && rc.isGlobal
					)
				)
				.setStatusCode( 201 );
		} catch (ContentEditor.Forbidden e) {
			prc.response.setErrorMessage( e.message, 403 );
		} catch (ContentEditor.Invalid e) {
			prc.response.setErrorMessage( e.message, 400 );
		}
	}

}