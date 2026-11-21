/**
 * The permissions Studio adds to ContentBox (models/StudioPermissions.cfc)
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"Studio permissions",
			() => {
				beforeEach(
					() => {
						setup();
						studioPermissions = getInstance( "StudioPermissions@contentbox-studio" );
						permissionService = getInstance( "permissionService@contentbox" );
					}
				);

				it(
					"are created when the module loads",
					() => {
						for ( var definition in studioPermissions.getDefinitions() ) {
							expect( permissionService.findByPermission( definition.permission ) ).notToBeNull(
								definition.permission
							);
						}
					}
				);

				it(
					"give the Administrator role everything",
					() => {
						var administrator = getInstance( "roleService@contentbox" ).findByRole( "Administrator" );
						expect( administrator.hasPermission( "STUDIO_ACCESS" ) ).toBeTrue();
						expect( administrator.hasPermission( "STUDIO_SITE_TREE" ) ).toBeTrue();
						expect( administrator.hasPermission( "STUDIO_HTML_BLOCKS" ) ).toBeTrue();
						expect( administrator.hasPermission( "STUDIO_CONVERT" ) ).toBeTrue();
					}
				);

				it(
					"give the Editor role access but no raw HTML blocks and no conversion",
					() => {
						var editor = getInstance( "roleService@contentbox" ).findByRole( "Editor" );
						expect( editor.hasPermission( "STUDIO_ACCESS" ) ).toBeTrue();
						expect( editor.hasPermission( "STUDIO_SITE_TREE" ) ).toBeTrue();
						expect( editor.hasPermission( "STUDIO_HTML_BLOCKS" ) ).toBeFalse();
						expect( editor.hasPermission( "STUDIO_CONVERT" ) ).toBeFalse();
					}
				);

				it(
					"are not created twice",
					() => {
						expect( studioPermissions.ensurePermissions() ).toBeEmpty();
					}
				);
			}
		);
	}

}