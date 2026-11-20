/**
 * The block types available on a site.
 *
 * A block type is a folder with a block.json (label, icon, category, version, fields) and a render.cfm.
 * Sources, later ones override earlier ones by name:
 *
 * 1. core: this module's blocks/ folder
 * 2. modules: folders registered with registerDirectory(), e.g. from a module's onLoad or from the
 * cbstudio_onBlockRegistration interception point ({ registry } in its data)
 * 3. theme: the blocks/ folder of the site's active theme
 *
 * The core "html" type (raw HTML) cannot be overridden. Block types with an invalid block.json are skipped and
 * logged, so a broken theme block never takes the site down. Definitions are cached per theme until reinit or
 * clearCache().
 */
component singleton {
	property name="blockData" inject="BlockData@contentbox-studio";

	property name="format" inject="BlockFormat@contentbox-studio";

	property name="themeService" inject="provider:themeService@contentbox";

	property name="interceptorService" inject="coldbox:interceptorService";

	property
		name="moduleConfig"
		inject="coldbox:moduleConfig:contentbox-studio";

	property name="log" inject="logbox:logger:{this}";
	variables.CONTENT_TYPES = [ "page", "entry", "contentStore" ];

	function init() {
		variables.sources = [];
		variables.cache = {};
		variables.announced = false;
		return this;
	}

	/**
	 * Add a folder of block types (one subfolder per type)
	 *
	 * @directory   Absolute path of the folder
	 * @includePath Path to include the folder's templates with, e.g. /mymodule/blocks
	 */
	function registerDirectory(
		required string directory,
		required string includePath,
		string source = "module"
	) {
		var exists = variables.sources.some( ( item ) => item.directory == directory );
		if ( !exists ) {
			variables.sources.append(
				{
					"directory"  : arguments.directory,
					"includePath": arguments.includePath,
					"source"     : arguments.source
				}
			);
			clearCache();
		}
		return this;
	}

	void function clearCache() {
		variables.cache = {};
	}

	/**
	 * Block types of a site's active theme, by name
	 */
	struct function forSite( required site ) {
		return forTheme( variables.themeService.getThemeRecord( arguments.site.getActiveTheme() ) );
	}

	/**
	 * Block types for a theme record of ContentBox's ThemeService ({ name, path, includePath }), by name
	 */
	struct function forTheme( required struct theme ) {
		announceRegistration();
		var key = arguments.theme.name & "|" & arguments.theme.path;
		if ( !variables.cache.keyExists( key ) ) {
			var types = loadDirectory(
				variables.moduleConfig.path & "/blocks",
				"/#variables.moduleConfig.classMapping#/blocks",
				"core"
			);
			for ( var source in variables.sources ) {
				types.append(
					loadDirectory(
						source.directory,
						source.includePath,
						source.source
					)
				);
			}
			types.append(
				loadDirectory(
					arguments.theme.path & "/" & arguments.theme.name & "/blocks",
					arguments.theme.includePath & "/blocks",
					"theme"
				)
			);
			variables.cache[ key ] = types;
		}
		return variables.cache[ key ];
	}

	/**
	 * Definitions for the editor: everything except template paths, sorted by category and label
	 */
	array function publicDefinitions( required struct types ) {
		var list = [];
		for ( var name in arguments.types ) {
			var definition = duplicate( arguments.types[ name ] );
			definition.delete( "renderTemplate" );
			list.append( definition );
		}
		list.sort(
			( a, b ) => compareNoCase( a.category & " " & a.label, b.category & " " & b.label )
		);
		return list;
	}

	/********************************* PRIVATE *********************************/

	private void function announceRegistration() {
		if ( !variables.announced ) {
			variables.announced = true;
			variables.interceptorService.announce( "cbstudio_onBlockRegistration", { "registry": this } );
		}
	}

	private struct function loadDirectory(
		required string directory,
		required string includePath,
		required string source
	) {
		var types = {};
		if ( !directoryExists( arguments.directory ) ) {
			return types;
		}
		var folders = directoryList(
			arguments.directory,
			false,
			"name",
			"",
			"name asc",
			"dir"
		);
		for ( var folder in folders ) {
			var folderPath = arguments.directory & "/" & folder;
			if ( !fileExists( folderPath & "/block.json" ) ) {
				continue;
			}
			try {
				var definition = readDefinition(
					folderPath,
					"#arguments.includePath#/#folder#/render.cfm",
					folder,
					arguments.source
				);
				if ( definition.name == "html" && arguments.source != "core" ) {
					variables.log.warn(
						"ContentBox Studio: the html block type cannot be overridden, ignored #folderPath#"
					);
					continue;
				}
				types[ definition.name ] = definition;
			} catch (any e) {
				variables.log.error(
					"ContentBox Studio: block type in #folderPath# skipped: #e.message#"
				);
			}
		}
		return types;
	}

	/**
	 * Content types the editor offers a block type for (page, entry, contentStore); all if none are given. Blocks of
	 * a type stay editable everywhere they already are.
	 */
	private array function contentTypes( any value ) {
		var types = isSimpleValue( arguments.value ) ? listToArray( arguments.value ) : arguments.value;
		if ( !isArray( types ) ) {
			types = [];
		}
		if ( !types.len() ) {
			return duplicate( variables.CONTENT_TYPES );
		}
		var result = [];
		for ( var type in types ) {
			var known = isSimpleValue( type ) ? variables.CONTENT_TYPES.findNoCase( type ) : 0;
			if ( !known ) {
				throw(
					type    = "BlockDefinition.Invalid",
					message = "contentTypes may only contain #variables.CONTENT_TYPES.toList( ", " )#"
				);
			}
			if ( !result.find( variables.CONTENT_TYPES[ known ] ) ) {
				result.append( variables.CONTENT_TYPES[ known ] );
			}
		}
		return result;
	}

	private struct function readDefinition(
		required string folderPath,
		required string renderTemplate,
		required string folder,
		required string source
	) {
		var json = deserializeJSON( fileRead( arguments.folderPath & "/block.json", "utf-8" ) );
		if ( !isStruct( json ) ) {
			throw(
				type    = "BlockDefinition.Invalid",
				message = "block.json must contain an object"
			);
		}
		var name = json.name ?: arguments.folder;
		if ( !isSimpleValue( name ) || !variables.format.isValidType( name ) ) {
			throw(
				type    = "BlockDefinition.Invalid",
				message = "invalid block name [#toString( name )#]"
			);
		}
		if ( name != "html" && !fileExists( arguments.folderPath & "/render.cfm" ) ) {
			throw(
				type    = "BlockDefinition.Invalid",
				message = "render.cfm is missing"
			);
		}
		return {
			"name"          : name,
			"label"         : json.label ?: name,
			"description"   : json.description ?: "",
			"icon"          : json.icon ?: "block",
			"category"      : json.category ?: "other",
			"version"       : isNumeric( json.version ?: "" ) && json.version >= 1 ? int( json.version ) : 1,
			"fields"        : variables.blockData.normalizeFields( json.fields ?: [], name ),
			"contentTypes"  : contentTypes( json.contentTypes ?: [] ),
			"source"        : arguments.source,
			"renderTemplate": arguments.renderTemplate
		};
	}

}