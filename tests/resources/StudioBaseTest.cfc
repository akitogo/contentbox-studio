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
	 * A fresh access token for the author
	 */
	string function tokenFor( required author ) {
		return getInstance( "JwtService@cbsecurity" ).fromUser( arguments.author ).access_token;
	}

}