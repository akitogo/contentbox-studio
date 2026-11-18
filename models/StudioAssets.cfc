/**
 * Script and stylesheet tags for the Studio app.
 *
 * Production: reads the Vite manifest in dist/.vite/manifest.json and links the hashed files in dist/.
 * Development: with the module setting `devServer` (env CBSTUDIO_DEV_SERVER) it loads the app from the Vite dev
 * server instead, with hot reload. See https://vite.dev/guide/backend-integration
 */
component singleton {
	property
		name="moduleSettings"
		inject="coldbox:moduleSettings:contentbox-studio";

	property name="moduleConfig" inject="coldbox:moduleConfig:contentbox-studio";
	variables.ENTRY = "src/main.tsx";

	/**
	 * @moduleRoot Web path of the module, e.g. /modules_app/contentbox-studio
	 *
	 * @return struct { head: link tags, body: script tags }, or throws StudioNotBuilt if dist/ is missing
	 */
	struct function getTags( required string moduleRoot ) {
		var devServer = variables
			.moduleSettings
			.devServer
			.reReplace( "/$", "" );
		if ( len( devServer ) ) {
			return { "head": "", "body": devServerScripts( devServer ) };
		}

		var manifest = readManifest();
		if ( !manifest.keyExists( variables.ENTRY ) ) {
			throw(
				type    = "StudioNotBuilt",
				message = "The Vite manifest has no entry for #variables.ENTRY#"
			);
		}
		var entry = manifest[ variables.ENTRY ];
		var distRoot = arguments.moduleRoot & "/dist/";

		// Not ( entry.css ?: [] ).map(): Adobe ColdFusion cannot call methods on a parenthesized expression
		var css = entry.css ?: [];
		var head = css.map(
			( file ) => "<link rel=""stylesheet"" href=""#distRoot##file#"">"
		);
		return {
			"head": head.toList( chr( 10 ) ),
			"body": "<script type=""module"" src=""#distRoot##entry.file#""></script>"
		};
	}

	private struct function readManifest() {
		var path = variables.moduleConfig.path & "/dist/.vite/manifest.json";
		if ( !fileExists( path ) ) {
			throw(
				type    = "StudioNotBuilt",
				message = "ContentBox Studio's app is not built: #path# is missing. Run `npm ci && npm run build` in ui/."
			);
		}
		return deserializeJSON( fileRead( path ) );
	}

	/**
	 * Vite client, React Refresh preamble (needed by @vitejs/plugin-react outside index.html) and the entry
	 */
	private string function devServerScripts( required string devServer ) {
		return [
			"<script type=""module"">",
			"import RefreshRuntime from ""#arguments.devServer#/@react-refresh"";",
			"RefreshRuntime.injectIntoGlobalHook(window);",
			"window.$RefreshReg$ = () => {};",
			"window.$RefreshSig$ = () => (type) => type;",
			"window.__vite_plugin_react_preamble_installed__ = true;",
			"</script>",
			"<script type=""module"" src=""#arguments.devServer#/@vite/client""></script>",
			"<script type=""module"" src=""#arguments.devServer#/#variables.ENTRY#""></script>"
		].toList( chr( 10 ) );
	}

}