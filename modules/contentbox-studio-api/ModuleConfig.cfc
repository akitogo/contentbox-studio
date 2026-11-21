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
		router.route( "/sites/:site/tree" ).to( "tree.index" );
		router.route( "/sites/:site/contentstore" ).to( "sites.contentStore" );
		router.route( "/sites/:site/templates" ).to( "sites.templates" );
		router.route( "/sites/:site/styles" ).to( "sites.styles" );
		router.route( "/sites/:site/pages" ).to( "tree.create" );
		router
			.route( "/sites/:site/entries" )
			.withAction( { "GET": "index", "POST": "create" } )
			.toHandler( "blog" );
		router.route( "/sites/:site/categories" ).to( "blog.categories" );
		router.route( "/sites" ).to( "sites.index" );
		router.route( "/pages/:contentID/move" ).to( "tree.move" );
		router.route( "/content/:contentID/language" ).to( "translations.setLanguage" );
		router
			.route( "/content/:contentID/translations" )
			.withAction( { "GET": "show", "POST": "link", "DELETE": "unlink" } )
			.toHandler( "translations" );
		router.route( "/content/:contentID/blocks" ).to( "editor.save" );
		router.route( "/content/:contentID/status" ).to( "editor.status" );
		router.route( "/content/:contentID/header" ).to( "editor.header" );
		router.route( "/content/:contentID/template" ).to( "editor.template" );
		router.route( "/content/:contentID/versions/:versionID" ).to( "editor.version" );
		router.route( "/content/:contentID/versions" ).to( "editor.versions" );
		router.route( "/content/:contentID" ).to( "editor.show" );
		router
			.route( "/media" )
			.withAction( { "GET": "index", "POST": "upload" } )
			.toHandler( "media" );
		router.route( "/blocks/render" ).to( "blocks.render" );
		router.route( "/blocks/rerender" ).to( "blocks.rerender" );
		router.route( "/blocks" ).to( "blocks.index" );
	}

}