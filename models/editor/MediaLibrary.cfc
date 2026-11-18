/**
 * Browsing and uploading files in ContentBox's media library (setting cb_media_directoryRoot), delivered by
 * ContentBox at /__media/<path>.
 *
 * Paths are always relative to the media root and checked against it, so nothing outside can be listed or written.
 * Uploads: images and PDFs only (no SVG: it can carry script), at most 20 MB, with a cleaned-up file name.
 */
component singleton {
	property name="mediaService" inject="mediaService@contentbox";
	variables.IMAGE_EXTENSIONS = "jpg,jpeg,png,gif,webp,avif";
	variables.UPLOAD_EXTENSIONS = variables.IMAGE_EXTENSIONS & ",pdf";
	variables.MAX_BYTES = 20 * 1024 * 1024;
	variables.FOLDER_PATTERN = "^[A-Za-z0-9 _./-]*$";

	/**
	 * @folder Path below the media root, "" for the root
	 *
	 * @return { folder, parent, folders: [ { name, path } ], files: [ { name, path, url, size, modified, isImage } ] }
	 */
	struct function list( string folder = "" ) {
		var relative = cleanFolder( arguments.folder );
		var absolute = resolve( relative );
		var result = {
			"folder" : relative,
			"parent" : listLen( relative, "/" ) > 1
				? listDeleteAt(
					relative,
					listLen( relative, "/" ),
					"/"
				)
				: "",
			"folders": [],
			"files"  : []
		};
		if ( !directoryExists( absolute ) ) {
			return result;
		}
		var entries = directoryList(
			absolute,
			false,
			"query"
		);
		for ( var row in entries ) {
			if ( left( row.name, 1 ) == "." ) {
				continue;
			}
			var path = len( relative ) ? relative & "/" & row.name : row.name;
			if ( row.type == "Dir" ) {
				result.folders.append( { "name": row.name, "path": path } );
			} else {
				result.files.append(
					describeFile(
						path,
						row.size,
						row.dateLastModified
					)
				);
			}
		}
		result.folders.sort( ( a, b ) => compareNoCase( a.name, b.name ) );
		result.files.sort( ( a, b ) => compareNoCase( a.name, b.name ) );
		return result;
	}

	/**
	 * Store an uploaded file (already on disk, e.g. from fileUpload() into a temp folder) in the media library
	 *
	 * @source       Absolute path of the uploaded file; moved, or deleted if refused
	 * @originalName The client's file name
	 * @folder       Target folder below the media root
	 *
	 * @return The stored file, like list().files
	 *
	 * @throws MediaLibrary.Refused
	 */
	struct function store(
		required string source,
		required string originalName,
		string folder = ""
	) {
		try {
			var extension = lCase( listLast( arguments.originalName, "." ) );
			if ( !listFind( variables.UPLOAD_EXTENSIONS, extension ) || !find( ".", arguments.originalName ) ) {
				refuse(
					"Only #variables.UPLOAD_EXTENSIONS# files can be uploaded"
				);
			}
			if ( getFileInfo( arguments.source ).size > variables.MAX_BYTES ) {
				refuse( "Files can be at most 20 MB" );
			}
			var relative = cleanFolder( arguments.folder );
			var target = resolve( relative );
			if ( !directoryExists( target ) ) {
				directoryCreate( target );
			}

			var baseName = reReplace(
				lCase(
					listDeleteAt(
						arguments.originalName,
						listLen( arguments.originalName, "." ),
						"."
					)
				),
				"[^a-z0-9_-]+",
				"-",
				"all"
			);
			baseName = reReplace(
				baseName,
				"^-+|-+$",
				"",
				"all"
			);
			if ( !len( baseName ) ) {
				baseName = "file";
			}
			var name = baseName & "." & extension;
			var counter = 1;
			while ( fileExists( target & "/" & name ) ) {
				counter++;
				name = baseName & "-" & counter & "." & extension;
			}
			fileMove( arguments.source, target & "/" & name );
		} catch (any e) {
			if ( fileExists( arguments.source ) ) {
				fileDelete( arguments.source );
			}
			rethrow;
		}

		var path = len( relative ) ? relative & "/" & name : name;
		var info = getFileInfo( target & "/" & name );
		return describeFile(
			path,
			info.size,
			info.lastModified
		);
	}

	/********************************* PRIVATE *********************************/

	private struct function describeFile(
		required string path,
		required numeric size,
		any modified
	) {
		var extension = lCase( listLast( arguments.path, "." ) );
		return {
			"name"    : listLast( arguments.path, "/" ),
			"path"    : arguments.path,
			// Path segments: encodeForURL() writes spaces as "+", which is wrong in a path
			"url"     : "/__media/" & arguments
				.path
				.listToArray( "/" )
				.map(
					( segment ) => replace(
						encodeForURL( segment ),
						"+",
						"%20",
						"all"
					)
				)
				.toList( "/" ),
			"size"    : arguments.size,
			"modified": isDate( arguments.modified ?: "" )
				? dateTimeFormat( arguments.modified, "yyyy-mm-dd'T'HH:nn:ss" )
				: "",
			"isImage" : listFind( variables.IMAGE_EXTENSIONS, extension ) > 0
		};
	}

	private string function cleanFolder( string folder = "" ) {
		var cleaned = reReplace(
			replace(
				trim( arguments.folder ),
				"\",
				"/",
				"all"
			),
			"^/+|/+$",
			"",
			"all"
		);
		if (
			!reFind( variables.FOLDER_PATTERN, cleaned ) ||
					listFind(
						cleaned,
						"..",
						"/"
					) ||
				listFind(
					cleaned,
					".",
					"/"
				)
		) {
			refuse( "Invalid folder" );
		}
		return cleaned;
	}

	/**
	 * Absolute path of a cleaned folder, checked to be inside the media root
	 */
	private string function resolve( required string relative ) {
		var root = createObject( "java", "java.io.File" ).init(
			variables.mediaService.getCoreMediaRoot( absolute = true )
		).getCanonicalPath();
		var absolute = createObject( "java", "java.io.File" ).init(
			root & "/" & arguments.relative
		).getCanonicalPath();
		if ( absolute != root && left( absolute, len( root ) + 1 ) != root & "/" ) {
			refuse( "Invalid folder" );
		}
		return absolute;
	}

	private void function refuse( required string message ) {
		throw( type = "MediaLibrary.Refused", message = arguments.message );
	}

}