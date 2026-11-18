/**
 * The author behind the token and what they may do in Studio
 */
component extends="BaseHandler" {
	this.allowedMethods = { "index": "GET" };

	/**
	 * GET /cbstudio/api/me
	 */
	function index( event, rc, prc ) {
		var author = jwtAuth().getUser();

		prc.response.setData(
			{
				"authorID"   : author.getAuthorID(),
				"username"   : author.getUsername(),
				"name"       : author.getFullName(),
				"email"      : author.getEmail(),
				"role"       : author.getRoleName(),
				"permissions": {
					"siteTree"  : author.hasPermission( "STUDIO_SITE_TREE" ),
					"htmlBlocks": author.hasPermission( "STUDIO_HTML_BLOCKS" )
				}
			}
		);
	}

}