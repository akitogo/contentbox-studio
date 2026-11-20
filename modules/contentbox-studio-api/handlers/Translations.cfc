/**
 * Translation groups of pages and blog entries
 */
component extends="BaseHandler" {
	property name="translations" inject="Translations@contentbox-studio";

	property name="contentEvents" inject="ContentEvents@contentbox-studio";
	this.allowedMethods = {
		"show"       : "GET",
		"setLanguage": "PUT",
		"link"       : "POST",
		"unlink"     : "DELETE"
	};

	/**
	 * GET /cbstudio/api/content/:contentID/translations
	 */
	function show( event, rc, prc ) {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		prc.response.setData( variables.translations.forContent( content ) );
	}

	/**
	 * PUT /cbstudio/api/content/:contentID/language with JSON { language }
	 */
	function setLanguage( event, rc, prc ) secured="STUDIO_SITE_TREE" {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		try {
			variables.translations.setLanguage( content, toString( rc.language ?: "" ) );
			var group = variables.translations.forContent( content );
			changed( group.members );
			prc.response.setData( group );
		} catch (Translations.Invalid e) {
			prc.response.setErrorMessage( e.message, 409 );
		}
	}

	/**
	 * POST /cbstudio/api/content/:contentID/translations with JSON { contentID } of the other version
	 */
	function link( event, rc, prc ) secured="STUDIO_SITE_TREE" {
		var content = findContent( rc.contentID ?: "" );
		var other = findContent( rc.translationID ?: "" );
		if ( isNull( content ) || isNull( other ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		try {
			variables.translations.link( content, other );
			var group = variables.translations.forContent( content );
			changed( group.members );
			prc.response.setData( group );
		} catch (Translations.Invalid e) {
			prc.response.setErrorMessage( e.message, 409 );
		}
	}

	/**
	 * DELETE /cbstudio/api/content/:contentID/translations: take the content out of its group
	 */
	function unlink( event, rc, prc ) secured="STUDIO_SITE_TREE" {
		var content = findContent( rc.contentID ?: "" );
		if ( isNull( content ) ) {
			prc.response.setErrorMessage( "Content not found", 404 );
			return;
		}
		var before = variables.translations.forContent( content ).members;
		variables.translations.unlink( content );
		changed( before );
		prc.response.setData( variables.translations.forContent( content ) );
	}

	/**
	 * The hreflang links in the head of these pages and entries changed: let ContentBox clear their cached output
	 *
	 * @members Group members (forContent().members)
	 */
	private void function changed( required array members ) {
		for ( var member in arguments.members ) {
			var item = findContent( member.contentID );
			if ( !isNull( item ) ) {
				variables.contentEvents.saved( item );
			}
		}
	}

}