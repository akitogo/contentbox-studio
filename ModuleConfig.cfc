/**
 * ContentBox Studio: block editor and site tree for ContentBox 7.
 *
 * Runs next to the classic admin (/cbadmin) at /cbstudio and uses ContentBox's own authors, roles and permissions:
 *
 * - /cbstudio serves the React app (built from ui/ into dist/). It needs a classic admin session with the
 * STUDIO_ACCESS permission; without one, cbsecurity sends the author to the admin login and back.
 * - The page hands the app JWT tokens for the logged-in author (like the classic admin editor does), which it
 * uses for the ContentBox REST API (/cbapi/v1) and the Studio API (/cbstudio/api, modules/contentbox-studio-api).
 */
component {
	this.title = "ContentBox Studio";
	this.author = "akitogo Internet and Media Applications GmbH";
	this.webURL = "https://github.com/akitogo/contentbox-studio";
	this.description = "Block editor and site tree for ContentBox 7";
	this.version = "0.1.0";
	this.entryPoint = "cbstudio";
	this.modelNamespace = "contentbox-studio";
	this.cfmapping = "contentbox-studio";
	this.dependencies = [ "contentbox" ];

	function configure() {
		settings = {
			// URL of the Vite dev server (e.g. http://localhost:5173) to load the app with hot reload instead of dist/
			"devServer" : getSystemSetting( "CBSTUDIO_DEV_SERVER", "" ),
			"cbsecurity": {
				"firewall": {
					// Not logged in: classic admin login, which returns to Studio afterwards
					"invalidAuthenticationEvent" : "cbadmin/security/login",
					"defaultAuthenticationAction": "redirect",
					// Logged in without STUDIO_ACCESS: explain it (a rule message would also show on the login page)
					"invalidAuthorizationEvent"  : "contentbox-studio:home.noAccess",
					"defaultAuthorizationAction" : "override",
					"rules"                      : [
						{
							"match"      : "event",
							"secureList" : "^contentbox\-studio\:",
							"whiteList"  : "^contentbox\-studio\:home\.noAccess$",
							"permissions": "STUDIO_ACCESS"
						}
					]
				}
			}
		};

		router.route( "/" ).to( "home.index" );
	}

	/**
	 * Create the Studio permissions and add Studio to the classic admin menu
	 */
	function onLoad() {
		wirebox.getInstance( "StudioPermissions@contentbox-studio" ).ensurePermissions();

		var menuService = wirebox.getInstance( "AdminMenuService@contentbox" );
		menuService.addSubMenu(
			topMenu     = menuService.CONTENT,
			name        = "contentbox-studio",
			label       = "Studio",
			title       = "Open ContentBox Studio",
			permissions = "STUDIO_ACCESS",
			href        = ( menu, event ) => event.buildLink( "cbstudio" )
		);
	}

	function onUnload() {
		var menuService = wirebox.getInstance( "AdminMenuService@contentbox" );
		menuService.removeSubMenu( topMenu = menuService.CONTENT, name = "contentbox-studio" );
	}

}