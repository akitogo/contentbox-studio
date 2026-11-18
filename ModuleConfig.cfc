/**
 * ContentBox Studio: block editor and site tree for ContentBox 7.
 *
 * Runs next to the classic admin (/cbadmin) at /cbstudio. Uses ContentBox's own authors, roles and permissions
 * and the ContentBox REST API (/cbapi/v1, JWT). The React app lives in ui/ and is built into dist/.
 */
component {

	this.title          = "ContentBox Studio";
	this.author         = "akitogo Internet and Media Applications GmbH";
	this.webURL         = "https://github.com/akitogo/contentbox-studio";
	this.description    = "Block editor and site tree for ContentBox 7";
	this.version        = "0.1.0";
	this.entryPoint     = "cbstudio";
	this.modelNamespace = "contentbox-studio";
	this.cfmapping      = "contentbox-studio";
	this.dependencies   = [ "contentbox" ];

	function configure(){
		settings = {};

		router.route( "/", "home.index" );
	}

}
