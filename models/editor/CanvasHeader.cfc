/**
 * The header of a blog entry in the editor canvas: what the theme's entry view shows above the content (title, date,
 * author, categories, featured image), so editing a post looks like the post.
 *
 * Themes provide it as blocks/_canvas/entry.cfm; without one, Studio's own (blocks/_canvas/entry.cfm of the module) is
 * used. The template gets args.data { title, date (formatted like ContentBox's display dates), publishedDate (date or
 * ""), author, categories: [ names ], image: { src, alt } }, args.studio and args.site, like a block template. It is
 * rendered with the values being edited, and the title is marked for editing in place like a text field.
 */
component singleton {
	property name="renderer" inject="BlockRenderer@contentbox-studio";

	property name="themeService" inject="provider:themeService@contentbox";

	property
		name="moduleConfig"
		inject="coldbox:moduleConfig:contentbox-studio";
	variables.TEMPLATE = "/blocks/_canvas/entry.cfm";
	variables.FIELDS = [ { "name": "title", "type": "text" } ];

	/**
	 * @content A page, entry or content store item; only entries have a header
	 * @values  Values being edited, each optional: { title, publishedDate (yyyy-mm-ddTHH:mm), categories: [ names ],
	 * featuredImage (URL) }; missing ones come from the content
	 *
	 * @return { html } ("" for other content types)
	 */
	struct function render( required content, struct values = {} ) {
		if ( lCase( arguments.content.getContentType() ) != "entry" ) {
			return { "html": "" };
		}
		var input = arguments.values;
		var published = input.keyExists( "publishedDate" )
			? dateOf( input.publishedDate )
			: arguments.content.getPublishedDate() ?: "";
		var categories = [];
		if ( isArray( input.categories ?: "" ) ) {
			for ( var name in input.categories ) {
				if ( isSimpleValue( name ) && len( trim( name ) ) ) {
					categories.append( trim( name ) );
				}
			}
		} else {
			for ( var category in arguments.content.getCategories() ?: [] ) {
				categories.append( category.getCategory() );
			}
		}
		var data = {
			"title"        : left( trim( text( input.title ?: arguments.content.getTitle() ) ), 200 ),
			"date"         : isDate( published ) ? dateFormat( published, arguments.content.DATE_FORMAT ) : "",
			"publishedDate": isDate( published ) ? published : "",
			"author"       : arguments.content.getAuthorName(),
			"categories"   : categories,
			"image"        : {
				"src": text( input.featuredImage ?: arguments.content.getFeaturedImageURL() ),
				"alt": ""
			}
		};
		return {
			"html": variables.renderer.renderBlock(
				{
					"name"          : "entryHeader",
					"fields"        : variables.FIELDS,
					"renderTemplate": templateFor(
						variables.themeService.getThemeRecord( arguments.content.getSite().getActiveTheme() )
					)
				},
				data,
				{
					"id"      : "header",
					"site"    : arguments.content.getSite(),
					"editable": true
				}
			)
		};
	}

	/**
	 * Include path of the header template: the theme's, else Studio's
	 *
	 * @theme A theme record of ContentBox's ThemeService ({ name, path, includePath })
	 */
	string function templateFor( required struct theme ) {
		if ( fileExists( arguments.theme.path & "/" & arguments.theme.name & variables.TEMPLATE ) ) {
			return arguments.theme.includePath & variables.TEMPLATE;
		}
		return "/#variables.moduleConfig.classMapping##variables.TEMPLATE#";
	}

	/********************************* PRIVATE *********************************/

	/**
	 * The date of a yyyy-mm-dd... value (time ignored: the header shows the day), "" for anything else
	 */
	private any function dateOf( any value = "" ) {
		var parts = reMatch( "\d+", text( arguments.value ) );
		if ( parts.len() < 3 || len( parts[ 1 ] ) != 4 ) {
			return "";
		}
		try {
			return createDate( parts[ 1 ], parts[ 2 ], parts[ 3 ] );
		} catch ( any e ) {
			return "";
		}
	}

	private string function text( any value = "" ) {
		return isSimpleValue( arguments.value ) ? toString( arguments.value ) : "";
	}

}
