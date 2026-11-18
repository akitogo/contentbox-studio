/**
 * Test bootstrap for ContentBox Studio, run inside a ContentBox site (module in modules_app/contentbox-studio).
 *
 * Reuses ContentBox's own test application (tests/Application.cfc of the site: mappings, ORM, virtual ColdBox app)
 * and only changes what Studio needs:
 * - its own application name, so it does not share state with ContentBox's suite
 * - the ORM dialect from ORM_DIALECT (env or .env), because ContentBox's suite hard-codes MySQL
 */
component extends="tests.Application" {
	this.name = "ContentBox Studio Testing Suite";

	if ( len( _studioSystemSetting( "ORM_DIALECT" ) ) ) {
		this.ormSettings.dialect = _studioSystemSetting( "ORM_DIALECT" );
	}

	this.mappings[ "/cbstudioTests" ] = getDirectoryFromPath( getCurrentTemplatePath() );

	private string function _studioSystemSetting( required string name ) {
		return server.system.environment[ arguments.name ] ?: server.system.properties[ arguments.name ] ?: "";
	}

}