/**
 * The settings of a blog entry that Studio edits next to its blocks: publish and expiry date, categories, excerpt,
 * featured image and comments. Saved with the blocks by ContentEditor.save(): prepare() checks everything before
 * anything changes, apply() changes the entry inside the save's transaction.
 */
component singleton {
	property name="categoryService" inject="categoryService@contentbox";

	property name="richText" inject="RichText@contentbox-studio";

	property name="htmlHelper" inject="HTMLHelper@coldbox";

	property name="contentStatus" inject="ContentStatus@contentbox-studio";
	// Column lengths in ContentBox
	variables.EXCERPT_LENGTH = 8000;
	variables.IMAGE_LENGTH = 500;
	variables.CATEGORY_LENGTH = 200;

	/**
	 * @return { categories: [ { categoryID, name, slug } ], excerpt (HTML), featuredImage, featuredImageURL,
	 * allowComments }
	 */
	struct function describe( required entry ) {
		// Not ( ... ?: [] ).map(): Adobe ColdFusion cannot call methods on a parenthesized expression
		var assigned = arguments.entry.getCategories() ?: [];
		var categories = assigned.map(
			( category ) => {
				return {
					"categoryID": category.getCategoryID(),
					"name"      : category.getCategory(),
					"slug"      : category.getSlug()
				};
			}
		);
		categories.sort( ( a, b ) => compareNoCase( a.name, b.name ) );
		return {
			"categories"      : categories,
			"excerpt"         : arguments.entry.getExcerpt() ?: "",
			"featuredImage"   : arguments.entry.getFeaturedImage() ?: "",
			"featuredImageURL": arguments.entry.getFeaturedImageURL(),
			"allowComments"   : arguments.entry.getAllowComments() ?: true
		};
	}

	/**
	 * Check the settings from the editor and resolve them, without changing anything
	 *
	 * @settings { publishedDate (yyyy-mm-ddTHH:mm, local time; empty: now), expireDate (same, empty: none),
	 * categories: [ { categoryID } or { name } (new or found by name) ], excerpt (rich text document),
	 * featuredImage ("/..." or http(s) URL, or the stored value), allowComments }
	 *
	 * @return The resolved settings for apply()
	 *
	 * @throws ContentEditor.Invalid
	 */
	struct function prepare( required entry, required struct settings ) {
		var values = arguments.settings;
		var site = arguments.entry.getSite();

		var publishedDate = len( text( values.publishedDate ?: "" ) )
			? localDate( values.publishedDate, "publish date" )
			: now();
		var expireDate = len( text( values.expireDate ?: "" ) ) ? localDate( values.expireDate, "expiry date" ) : "";
		if ( isDate( expireDate ) && expireDate <= publishedDate ) {
			invalid( "The expiry date must be after the publish date" );
		}

		var existing = [];
		var newNames = [];
		for ( var item in isArray( values.categories ?: "" ) ? values.categories : [] ) {
			if ( !isStruct( item ) ) {
				invalid( "Categories must be given as { categoryID } or { name }" );
			}
			var id = text( item.categoryID ?: "" );
			if ( len( id ) ) {
				var category = variables.categoryService.get( id = id, returnNew = false );
				if ( isNull( category ) || category.getSite().getSiteID() != site.getSiteID() ) {
					invalid( "The category #id# does not exist on this site" );
				}
				add( existing, category );
				continue;
			}
			var name = trim( text( item.name ?: "" ) );
			if ( !len( name ) ) {
				continue;
			}
			if ( len( name ) > variables.CATEGORY_LENGTH ) {
				invalid(
					"A category name may have at most #variables.CATEGORY_LENGTH# characters"
				);
			}
			var found = findCategory( site, name );
			if ( isNull( found ) ) {
				newNames.append( name );
			} else {
				add( existing, found );
			}
		}

		var excerpt = variables.richText.isEmpty( values.excerpt ?: "" )
			? ""
			: variables.richText.toHTML( values.excerpt );
		if ( len( excerpt ) > variables.EXCERPT_LENGTH ) {
			invalid( "The excerpt is too long" );
		}

		var image = trim( text( values.featuredImage ?: "" ) );
		if (
			len( image ) && image != ( arguments.entry.getFeaturedImage() ?: "" ) &&
				!reFindNoCase( "^(/[^/]|https?://)", image )
		) {
			invalid(
				"The featured image must be an address on the site (/...) or an http(s) URL"
			);
		}
		if ( len( image ) > variables.IMAGE_LENGTH ) {
			invalid(
				"The featured image address may have at most #variables.IMAGE_LENGTH# characters"
			);
		}

		return {
			"publishedDate": publishedDate,
			"expireDate"   : expireDate,
			"categories"   : existing,
			"newCategories": newNames,
			"excerpt"      : excerpt,
			"featuredImage": image,
			"allowComments": isBoolean( values.allowComments ?: "" ) ? values.allowComments : true
		};
	}

	/**
	 * Change the entry (inside the caller's transaction; the caller saves it)
	 */
	void function apply( required entry, required struct prepared ) {
		var categories = arguments.prepared.categories;
		var seen = {};
		for ( var name in arguments.prepared.newCategories ) {
			if ( seen.keyExists( name ) ) {
				continue;
			}
			seen[ name ] = true;
			var category = variables.categoryService.new(
				{
					"category": name,
					"slug"    : uniqueSlug( arguments.entry.getSite(), name ),
					"site"    : arguments.entry.getSite()
				}
			);
			// entitySave(): CategoryService.save() would open its own transaction inside the save's
			entitySave( category );
			categories.append( category );
		}
		arguments
			.entry
			.removeAllCategories()
			.setCategories( categories );
		arguments.entry.setPublishedDate( arguments.prepared.publishedDate );
		if ( isDate( arguments.prepared.expireDate ) ) {
			arguments.entry.setExpireDate( arguments.prepared.expireDate );
		} else {
			arguments.entry.setExpireDate( javacast( "null", "" ) );
		}
		arguments.entry.setExcerpt( arguments.prepared.excerpt );
		arguments.entry.setFeaturedImage( arguments.prepared.featuredImage );
		arguments.entry.setAllowComments( arguments.prepared.allowComments );
	}

	/********************************* PRIVATE *********************************/

	/**
	 * Add a category once (it may be given by id and by name)
	 */
	private void function add( required array categories, required category ) {
		for ( var item in arguments.categories ) {
			if ( item.getCategoryID() == arguments.category.getCategoryID() ) {
				return;
			}
		}
		arguments.categories.append( arguments.category );
	}

	/**
	 * A date from a datetime-local field (yyyy-mm-ddTHH:mm[:ss])
	 */
	private date function localDate( required any value, required string label ) {
		var parts = reMatch( "\d+", text( arguments.value ) );
		if (
			!reFind(
					"^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2})?$",
					text( arguments.value )
				) ||
				!isValidDate( parts )
		) {
			invalid( "The #arguments.label# is not a date and time" );
		}
		return createDateTime(
			parts[ 1 ],
			parts[ 2 ],
			parts[ 3 ],
			parts[ 4 ],
			parts[ 5 ],
			parts.len() > 5 ? parts[ 6 ] : 0
		);
	}

	private boolean function isValidDate( required array parts ) {
		return arguments.parts[ 2 ] >= 1 && arguments.parts[ 2 ] <= 12 && arguments.parts[ 3 ] >= 1 &&
					arguments.parts[ 3 ] <=
						daysInMonth(
							createDate(
								arguments.parts[ 1 ],
								arguments.parts[ 2 ],
								1
							)
						) &&
				arguments.parts[ 4 ] <= 23 &&
			arguments.parts[ 5 ] <= 59;
	}

	/**
	 * A category of the site with this name or slug (case-insensitive)
	 */
	private function findCategory( required site, required string name ) {
		var slug = variables.htmlHelper.slugify( arguments.name );
		for ( var category in variables
			.categoryService
			.newCriteria()
			.isEq( "site.siteID", arguments.site.getSiteID() )
			.list() ) {
			if ( category.getCategory() == arguments.name || category.getSlug() == slug ) {
				return category;
			}
		}
	}

	private string function uniqueSlug( required site, required string name ) {
		var base = variables.htmlHelper.slugify( arguments.name );
		if ( !len( base ) ) {
			base = "category";
		}
		var slug = base;
		var i = 1;
		while ( !variables.categoryService.isSlugUnique( slug = slug, siteID = arguments.site.getSiteID() ) ) {
			i++;
			slug = "#base#-#i#";
		}
		return slug;
	}

	private string function text( any value = "" ) {
		return isSimpleValue( arguments.value ) ? toString( arguments.value ) : "";
	}

	private void function invalid( required string message ) {
		throw( type = "ContentEditor.Invalid", message = arguments.message );
	}

}