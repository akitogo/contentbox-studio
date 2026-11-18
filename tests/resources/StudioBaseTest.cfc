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
	 * @publishedDate Publish date, defaults to now
	 */
	function createTestPage(
		required string slug,
		any parent          = "",
		boolean isPublished = true,
		any publishedDate   = now(),
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
	string function tokenFor( required author ) {
		return getInstance( "JwtService@cbsecurity" ).fromUser( arguments.author ).access_token;
	}

}