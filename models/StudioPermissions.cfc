/**
 * The ContentBox permissions Studio adds, and their setup.
 *
 * Missing permissions are created on module load and granted to their default roles. Existing permissions are
 * never changed, so what an administrator configures in the classic admin (roles, groups, authors) is kept.
 */
component singleton accessors="true" {
	property name="permissionService" inject="permissionService@contentbox";

	property name="roleService" inject="roleService@contentbox";

	property name="settingService" inject="settingService@contentbox";

	property name="log" inject="logbox:logger:{this}";

	/**
	 * Permission name, description and the roles that get it when it is created
	 */
	property name="definitions" type="array";

	function init() {
		variables.definitions = [
			{
				"permission" : "STUDIO_ACCESS",
				"description": "Access to ContentBox Studio",
				"roles"      : [ "Administrator", "Editor" ]
			},
			{
				"permission" : "STUDIO_SITE_TREE",
				"description": "Move and reorder pages in the ContentBox Studio site tree",
				"roles"      : [ "Administrator", "Editor" ]
			},
			{
				"permission" : "STUDIO_HTML_BLOCKS",
				"description": "Add and edit raw HTML blocks in ContentBox Studio",
				"roles"      : [ "Administrator" ]
			}
		];
		return this;
	}

	/**
	 * Create missing Studio permissions and grant each new one to its default roles.
	 * Does nothing before ContentBox is installed: the module loads again after the installer restarts the app.
	 *
	 * @return The names of the permissions that were created
	 */
	array function ensurePermissions() {
		if ( !variables.settingService.isCBReady() ) {
			return [];
		}

		var created = [];
		lock name   ="contentbox-studio-permissions" type   ="exclusive" timeout="30" {
			transaction {
				for ( var definition in variables.definitions ) {
					if ( !isNull( variables.permissionService.findByPermission( definition.permission ) ) ) {
						continue;
					}

					var oPermission = variables.permissionService.new(
						{
							"permission" : definition.permission,
							"description": definition.description
						}
					);
					variables.permissionService.save( entity = oPermission, transactional = false );

					for ( var roleName in definition.roles ) {
						var oRole = variables.roleService.findByRole( roleName );
						if ( isNull( oRole ) ) {
							continue;
						}
						var rolePermissions = [];
						rolePermissions.addAll( oRole.getPermissions() ?: [] );
						rolePermissions.append( oPermission );
						oRole.setPermissions( rolePermissions );
						variables.roleService.save( entity = oRole, transactional = false );
					}

					created.append( definition.permission );
				}
			}
		}

		if ( created.len() ) {
			variables.log.info(
				"ContentBox Studio created permissions: #created.toList()#"
			);
		}
		return created;
	}

}