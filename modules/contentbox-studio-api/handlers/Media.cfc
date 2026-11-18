/**
 * ContentBox's media library for the image and link pickers
 */
component extends="BaseHandler" {
	property name="mediaLibrary" inject="MediaLibrary@contentbox-studio";
	this.allowedMethods = { "index": "GET", "upload": "POST" };

	/**
	 * GET /cbstudio/api/media?folder=images/rooms
	 */
	function index( event, rc, prc ) {
		try {
			prc.response.setData(
				variables.mediaLibrary.list(
					isSimpleValue( rc.folder ?: "" ) ? toString( rc.folder ?: "" ) : ""
				)
			);
		} catch (MediaLibrary.Refused e) {
			prc.response.setErrorMessage( e.message, 400 );
		}
	}

	/**
	 * POST /cbstudio/api/media as multipart form: file, folder. Needs MEDIAMANAGER_ADMIN.
	 */
	function upload( event, rc, prc ) secured="MEDIAMANAGER_ADMIN" {
		if ( !len( rc.file ?: "" ) ) {
			return prc.response.setErrorMessage( "No file uploaded", 400 );
		}
		var temp = getTempDirectory() & "cbstudio-uploads";
		if ( !directoryExists( temp ) ) {
			directoryCreate( temp );
		}
		try {
			var uploaded = fileUpload(
				temp,
				"file",
				"",
				"makeUnique"
			);
			var source = uploaded.serverDirectory & "/" & uploaded.serverFile;
			prc.response.setData(
				variables.mediaLibrary.store(
					source       = source,
					originalName = uploaded.clientFile,
					folder       = isSimpleValue( rc.folder ?: "" ) ? toString( rc.folder ?: "" ) : ""
				)
			);
		} catch (MediaLibrary.Refused e) {
			prc.response.setErrorMessage( e.message, 400 );
		}
	}

}