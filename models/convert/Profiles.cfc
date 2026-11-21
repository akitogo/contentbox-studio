/**
 * Conversion profiles: how the old HTML of a site becomes blocks of one target theme.
 *
 * A profile is a folder with a profile.json, in modules_app/contentbox-custom/_convert/ (or a folder registered with
 * registerDirectory()). Profiles are needed once per site and are often specific to it, so they belong to neither the
 * old nor the new theme:
 *
 * {
 *   "label": "Old site to Studio Starter",
 *   "theme": "studio-starter",       the theme whose blocks the rules produce (the site's active theme)
 *   "compare": "content",            "markup" when the blocks reproduce the old HTML, "content" for a new look
 *   "rules": [                       tried in order for each top-level section
 *     { "block": "hero", "match": "section.hero", "fields": { "title": "h1", "image": "img" } },
 *     { "block": "team", "match": "section.team", "reader": "team" }
 *   ]
 * }
 *
 * A rule with "reader" uses readers/<name>.cfc of the profile instead of "fields": its read( element, read ) returns
 * the block data, or nothing when the section is not this block; read is the FieldReader with its helpers.
 *
 * "prose": true turns sections no rule matches into Studio's text, heading and image blocks where they are plain
 * text (paragraphs, headings, lists, quotes, images); it needs "compare": "content". "theme": "*" is any theme. The
 * built-in profile "plain-text" does just that, without rules, for any site.
 */
component singleton {
	property name="controller" inject="coldbox";

	property name="log" inject="logbox:logger:{this}";

	variables.registered = [];
	variables.ANY_THEME = "*";
	variables.BUILTIN = {
		"plain-text": {
			"label"  : "Plain text into Studio's blocks (any theme)",
			"theme"  : variables.ANY_THEME,
			"compare": "content",
			"prose"  : true
		}
	};
	variables.NAME_PATTERN = "^[A-Za-z0-9_-]+$";
	variables.COMPARE = "markup,content";

	/**
	 * Add a folder of profiles (each profile a subfolder)
	 *
	 * @directory      Absolute path
	 * @invocationPath Dotted component path of the folder, for code readers
	 */
	void function registerDirectory( required string directory, required string invocationPath ) {
		for ( var source in variables.registered ) {
			if ( source.directory == arguments.directory ) {
				return;
			}
		}
		variables.registered.append( { "directory": arguments.directory, "invocationPath": arguments.invocationPath } );
	}

	/**
	 * All profiles, sorted by label
	 *
	 * @return [ { name, label, theme, compare, prose, problems } ]
	 */
	array function list() {
		var result = [];
		var seen = {};
		for ( var source in sources() ) {
			if ( !directoryExists( source.directory ) ) {
				continue;
			}
			for ( var name in directoryList( source.directory, false, "name", "", "name asc", "dir" ) ) {
				if ( seen.keyExists( name ) || !reFind( variables.NAME_PATTERN, name ) ) {
					continue;
				}
				if ( !fileExists( source.directory & "/" & name & "/profile.json" ) ) {
					continue;
				}
				seen[ name ] = true;
				result.append( summary( load( source, name ) ) );
			}
		}
		for ( var name in variables.BUILTIN ) {
			if ( !seen.keyExists( name ) ) {
				result.append( summary( builtinProfile( name ) ) );
			}
		}
		result.sort( ( a, b ) => compareNoCase( a.label, b.label ) );
		return result;
	}

	/**
	 * A profile with its rules, read from disk each time (profiles change while they are written)
	 *
	 * @return { name, label, theme, compare, prose, rules: [ { block, match, fields, reader } ], problems: [], directory,
	 * invocationPath }
	 *
	 * @throws Convert.ProfileNotFound
	 */
	struct function get( required string name ) {
		if ( reFind( variables.NAME_PATTERN, arguments.name ) ) {
			for ( var source in sources() ) {
				if ( fileExists( source.directory & "/" & arguments.name & "/profile.json" ) ) {
					return load( source, arguments.name );
				}
			}
			if ( variables.BUILTIN.keyExists( arguments.name ) ) {
				return builtinProfile( arguments.name );
			}
		}
		throw( type = "Convert.ProfileNotFound", message = "No conversion profile '#arguments.name#'" );
	}

	/**
	 * Whether a profile is for any theme ("theme": "*")
	 */
	boolean function anyTheme( required struct profile ) {
		return arguments.profile.theme == variables.ANY_THEME;
	}

	/**
	 * A new instance of a profile's code reader (readers/<name>.cfc)
	 */
	function reader( required struct profile, required string name ) {
		return createObject( "component", arguments.profile.invocationPath & ".readers." & arguments.name );
	}

	/********************************* PRIVATE *********************************/

	private struct function summary( required struct profile ) {
		return {
			"name"    : arguments.profile.name,
			"label"   : arguments.profile.label,
			"theme"   : arguments.profile.theme,
			"compare" : arguments.profile.compare,
			"prose"   : arguments.profile.prose,
			"problems": arguments.profile.problems
		};
	}

	private struct function builtinProfile( required string name ) {
		var profile = duplicate( variables.BUILTIN[ arguments.name ] );
		profile.append( {
			"name"          : arguments.name,
			"rules"         : [],
			"problems"      : [],
			"directory"     : "",
			"invocationPath": ""
		} );
		return profile;
	}

	/**
	 * Registered folders plus contentbox-custom/_convert, if that module is loaded
	 */
	private array function sources() {
		var result = duplicate( variables.registered );
		var modules = variables.controller.getSetting( "modules" );
		if ( modules.keyExists( "contentbox-custom" ) ) {
			var custom = modules[ "contentbox-custom" ];
			result.append( {
				"directory"     : custom.path & "/_convert",
				"invocationPath": custom.invocationPath & "._convert"
			} );
		}
		return result;
	}

	private struct function load( required struct source, required string name ) {
		var directory = arguments.source.directory & "/" & arguments.name;
		var profile = {
			"name"          : arguments.name,
			"label"         : arguments.name,
			"theme"         : "",
			"compare"       : "markup",
			"prose"         : false,
			"rules"         : [],
			"problems"      : [],
			"directory"     : directory,
			"invocationPath": arguments.source.invocationPath & "." & arguments.name
		};
		var raw = fileRead( directory & "/profile.json" );
		if ( !isJSON( raw ) ) {
			profile.problems.append( "profile.json is not valid JSON" );
			return profile;
		}
		var data = deserializeJSON( raw );
		if ( !isStruct( data ) ) {
			profile.problems.append( "profile.json must be an object" );
			return profile;
		}
		if ( isSimpleValue( data.label ?: "" ) && len( trim( data.label ?: "" ) ) ) {
			profile.label = trim( data.label );
		}
		if ( isSimpleValue( data.theme ?: "" ) && len( trim( data.theme ?: "" ) ) ) {
			profile.theme = trim( data.theme );
		} else {
			profile.problems.append( "theme is missing: the theme whose blocks the rules produce" );
		}
		if ( data.keyExists( "compare" ) ) {
			if ( isSimpleValue( data.compare ) && listFind( variables.COMPARE, data.compare ) ) {
				profile.compare = data.compare;
			} else {
				profile.problems.append( "compare must be ""markup"" or ""content""" );
			}
		}
		if ( data.keyExists( "prose" ) ) {
			if ( isBoolean( data.prose ) ) {
				profile.prose = data.prose == true;
			} else {
				profile.problems.append( "prose must be true or false" );
			}
		}
		if ( profile.prose && profile.compare != "content" ) {
			profile.problems.append( "prose needs ""compare"": ""content"" (Studio's blocks look different from the old HTML)" );
		}
		// Without prose, rules are what the profile does
		if ( !isArray( data.rules ?: "" ) || ( !data.rules.len() && !profile.prose ) ) {
			profile.problems.append( "rules is missing or empty" );
			return profile;
		}
		var index = 0;
		for ( var item in data.rules ) {
			index++;
			var rule = ruleOf( item, index, profile );
			if ( !isNull( rule ) ) {
				profile.rules.append( rule );
			}
		}
		return profile;
	}

	/**
	 * A checked rule, or nothing with its problems added to the profile (arrays are passed by value on Adobe, so the
	 * profile is passed)
	 */
	private function ruleOf( required any item, required numeric index, required struct profile ) {
		var label = "Rule #arguments.index#";
		if ( !isStruct( arguments.item ) ) {
			arguments.profile.problems.append( "#label# must be an object" );
			return;
		}
		var rule = {
			"block" : isSimpleValue( arguments.item.block ?: "" ) ? trim( arguments.item.block ?: "" ) : "",
			"match" : isSimpleValue( arguments.item.match ?: "" ) ? trim( arguments.item.match ?: "" ) : "",
			"reader": isSimpleValue( arguments.item.reader ?: "" ) ? trim( arguments.item.reader ?: "" ) : "",
			"fields": isStruct( arguments.item.fields ?: "" ) ? arguments.item.fields : {}
		};
		var count = arguments.profile.problems.len();
		if ( !len( rule.block ) ) {
			arguments.profile.problems.append( "#label#: block is missing" );
		} else {
			label &= " (#rule.block#)";
		}
		if ( len( rule.reader ) ) {
			if ( !reFind( variables.NAME_PATTERN, rule.reader ) ) {
				arguments.profile.problems.append( "#label#: invalid reader name" );
			} else if ( !fileExists( arguments.profile.directory & "/readers/" & rule.reader & ".cfc" ) ) {
				arguments.profile.problems.append( "#label#: readers/#rule.reader#.cfc not found" );
			}
		} else {
			if ( !len( rule.match ) ) {
				arguments.profile.problems.append( "#label#: match is missing (a CSS selector for the section)" );
			}
			if ( !isStruct( arguments.item.fields ?: "" ) ) {
				arguments.profile.problems.append( "#label#: fields is missing" );
			}
		}
		// A rule with a problem is left out; any problem makes the profile unusable
		if ( arguments.profile.problems.len() == count ) {
			return rule;
		}
	}

}
