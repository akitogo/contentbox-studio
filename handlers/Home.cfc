/**
 * Entry point of ContentBox Studio. For now only proves that the module is loaded.
 */
component {

	function index( event, rc, prc ){
		return {
			"name"    : "ContentBox Studio",
			"version" : getModuleConfig( "contentbox-studio" ).version,
			"status"  : "skeleton"
		};
	}

}
