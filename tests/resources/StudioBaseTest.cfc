/**
 * Base for Studio's specs: ContentBox's integration base (virtual ColdBox app) plus author helpers.
 * The helpers look authors up by role, because the CI fixture and a local install have different usernames.
 * Services come from getInstance(): specs only get property injection for their own properties, not a base's.
 */
component extends="tests.resources.BaseTest" {

	function getSecurityService() {
		return getInstance( "securityService@contentbox" );
	}

	/**
	 * An active author with the Administrator role
	 */
	function getAdministrator() {
		var authors = getInstance( "authorService@contentbox" )
			.newCriteria()
			.createAlias( "role", "r" )
			.isEq( "r.role", "Administrator" )
			.isTrue( "isActive" )
			.list( max = 1 );
		if ( !authors.len() ) {
			throw(
				type    = "StudioTestSetup",
				message = "The test database has no active Administrator"
			);
		}
		return authors[ 1 ];
	}

	/**
	 * Run a closure with a temporary active author whose role has no permissions; both are deleted afterwards
	 *
	 * @target Receives the author
	 */
	function withAuthorWithoutStudioAccess( required target ) {
		return withTemporaryAuthor( [], arguments.target );
	}

	/**
	 * Run a closure with a temporary active author whose role has exactly the given permissions; author and role are
	 * deleted afterwards
	 *
	 * @permissions Permission names, e.g. [ "STUDIO_ACCESS" ]
	 * @target      Receives the author
	 */
	function withTemporaryAuthor( required array permissions, required target ) {
		var authorService = getInstance( "authorService@contentbox" );
		var roleService = getInstance( "roleService@contentbox" );
		var permissionService = getInstance( "permissionService@contentbox" );
		var suffix = lCase(
			left(
				replace(
					createUUID(),
					"-",
					"",
					"all"
				),
				12
			)
		);

		var role = roleService.new(
			{
				"role"       : "studio-test-#suffix#",
				"description": "Temporary role for ContentBox Studio tests"
			}
		);
		role.setPermissions(
			arguments.permissions.map( ( name ) => permissionService.findByPermission( name ) )
		);
		roleService.save( role );

		var author = authorService.new(
			{
				"firstName": "Studio",
				"lastName" : "Test",
				"email"    : "studio-test-#suffix#@example.test",
				"username" : "studio-test-#suffix#",
				"password" : createUUID(),
				"isActive" : true
			}
		);
		author.setRole( role );
		authorService.save( author = author, passwordChange = true );

		try {
			return arguments.target( author );
		} finally {
			getSecurityService().logout();
			authorService.delete( authorService.get( author.getAuthorID() ) );
			roleService.delete( roleService.get( role.getRoleID() ) );
		}
	}

	/**
	 * Create and save a page on the default site with one content version
	 *
	 * @slug          Last slug segment (the parent's slug is put in front)
	 * @parent        Parent page or ""
	 * @isPublished   Published flag
	 * @publishedDate Publish date, defaults to 5 minutes ago (MySQL rounds fractional seconds up, so "now" can be stored
	 * as a moment in the future and the page would count as scheduled)
	 */
	function createTestPage(
		required string slug,
		any parent          = "",
		boolean isPublished = true,
		any publishedDate   = dateAdd(
			"n",
			-5,
			now()
		),
		string body         = "<p>Studio test page</p>"
	) {
		var pageService = getInstance( "pageService@contentbox" );
		var author = getAdministrator();
		var page = pageService.new(
			{
				"title"        : arguments.slug,
				"slug"         : arguments.slug,
				"isPublished"  : arguments.isPublished,
				"publishedDate": arguments.publishedDate,
				"site"         : getInstance( "siteService@contentbox" ).getDefaultSite(),
				"creator"      : author
			}
		);
		if ( isObject( arguments.parent ) ) {
			page.setParent( arguments.parent );
		}
		page.addNewContentVersion(
			content   = arguments.body,
			changelog = "ContentBox Studio test",
			author    = author
		);
		return pageService.save( page );
	}

	/**
	 * Delete test pages whose slug contains the marker (children first) and relocations created for them
	 */
	function deleteTestPages( required string marker ) {
		ormClearSession();
		var pageService = getInstance( "pageService@contentbox" );
		var pages = pageService
			.newCriteria()
			.like( "slug", "%#arguments.marker#%" )
			.list();
		pages.sort( ( a, b ) => len( b.getSlug() ) - len( a.getSlug() ) );
		for ( var page in pages ) {
			pageService.delete( page );
		}
		queryExecute(
			"DELETE FROM cb_relocations WHERE slug LIKE :marker",
			{ "marker": "%#arguments.marker#%" }
		);
		ormClearSession();
	}

	/**
	 * Create and save a blog entry on the default site with one content version
	 *
	 * @categories Categories to put it in
	 */
	function createTestEntry(
		required string slug,
		boolean isPublished = true,
		any publishedDate   = dateAdd(
			"n",
			-5,
			now()
		),
		any expireDate      = "",
		array categories    = [],
		string body         = "<p>Studio test entry</p>"
	) {
		var entryService = getInstance( "entryService@contentbox" );
		var author = getAdministrator();
		var entry = entryService.new(
			{
				"title"        : arguments.slug,
				"slug"         : arguments.slug,
				"isPublished"  : arguments.isPublished,
				"publishedDate": arguments.publishedDate,
				"site"         : getInstance( "siteService@contentbox" ).getDefaultSite(),
				"creator"      : author
			}
		);
		if ( isDate( arguments.expireDate ) ) {
			entry.setExpireDate( arguments.expireDate );
		}
		if ( arguments.categories.len() ) {
			entry.setCategories( arguments.categories );
		}
		entry.addNewContentVersion(
			content   = arguments.body,
			changelog = "ContentBox Studio test",
			author    = author
		);
		return entryService.save( entry );
	}

	/**
	 * Create and save a category on the default site
	 */
	function createTestCategory( required string slug ) {
		var categoryService = getInstance( "categoryService@contentbox" );
		return categoryService.save(
			categoryService.new(
				{
					"category": arguments.slug,
					"slug"    : arguments.slug,
					"site"    : getInstance( "siteService@contentbox" ).getDefaultSite()
				}
			)
		);
	}

	/**
	 * Delete test entries and categories whose slug contains the marker
	 */
	function deleteTestEntries( required string marker ) {
		ormClearSession();
		var entryService = getInstance( "entryService@contentbox" );
		for ( var entry in entryService
			.newCriteria()
			.like( "slug", "%#arguments.marker#%" )
			.list() ) {
			entryService.delete( entry );
		}
		var categoryService = getInstance( "categoryService@contentbox" );
		for ( var category in categoryService
			.newCriteria()
			.like( "slug", "%#arguments.marker#%" )
			.list() ) {
			categoryService.delete( category );
		}
		ormClearSession();
	}

	/**
	 * A unique slug segment for test content
	 */
	string function testSlug( required string prefix ) {
		return "#arguments.prefix#-#lCase(
			left(
				replace(
					createUUID(),
					"-",
					"",
					"all"
				),
				8
			)
		)#";
	}

	/**
	 * A fresh access token for the author
	 */
	/**
	 * The HTTP status ColdBox renders for a request (event.getRenderData()), not just what prc.response holds:
	 * an action that returns a value skips RestHandler's rendering, so both can differ
	 */
	numeric function renderedStatus( required event ) {
		var rendered = arguments.event.getRenderData();
		// No ?: here: Adobe ColdFusion 2023 returned a non-numeric value with it
		if ( !structKeyExists( rendered, "statusCode" ) || !isNumeric( rendered.statusCode ) ) {
			return 0;
		}
		return val( rendered.statusCode );
	}

	string function tokenFor( required author ) {
		return getInstance( "JwtService@cbsecurity" ).fromUser( arguments.author ).access_token;
	}

}