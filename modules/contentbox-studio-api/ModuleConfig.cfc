/**
 * ContentBox Studio API: endpoints the ContentBox REST API (/cbapi/v1) does not have.
 *
 * Authenticated like /cbapi/v1: a JWT in the Authorization bearer header or x-auth-token, issued by the Studio page
 * or POST /cbapi/v1/login. Every endpoint needs the STUDIO_ACCESS permission.
 */
component {
	this.title = "ContentBox Studio API";
	this.author = "akitogo Internet and Media Applications GmbH";
	this.webURL = "https://github.com/akitogo/contentbox-studio";
	this.description = "REST API of ContentBox Studio";
	this.entryPoint = "cbstudio/api";
	this.modelNamespace = "contentbox-studio-api";
	this.classMapping = "contentbox-studio-api";
	this.dependencies = [];

	function configure() {
		settings = {
			"cbsecurity": {
				"firewall": {
					"validator"                  : "JwtAuthValidator@cbsecurity",
					"invalidAuthenticationEvent" : "contentbox-studio-api:BaseHandler.onAuthenticationFailure",
					"defaultAuthenticationAction": "override",
					"invalidAuthorizationEvent"  : "contentbox-studio-api:BaseHandler.onAuthorizationFailure",
					"defaultAuthorizationAction" : "override",
					"rules"                      : [
						{
							"match"      : "event",
							"secureList" : "^contentbox\-studio\-api\:",
							"whiteList"  : "^contentbox\-studio\-api\:BaseHandler\.",
							"permissions": "STUDIO_ACCESS"
						}
					]
				}
			}
		};

		router.route( "/me" ).to( "me.index" );
		router.route( "/sites" ).to( "sites.index" );
		router.route( "/blocks/render" ).to( "blocks.render" );
		router.route( "/blocks" ).to( "blocks.index" );
	}

}