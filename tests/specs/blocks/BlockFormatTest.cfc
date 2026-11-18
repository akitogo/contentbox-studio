/**
 * models/blocks/BlockFormat.cfc against the shared fixtures in tests/fixtures/block-format
 * (the same fixtures as ui/src/blocks/format.test.ts)
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"Block format",
			() => {
				beforeEach(
					() => {
						format = getInstance( "BlockFormat@contentbox-studio" );
					}
				);

				it(
					"matches Java String.hashCode as unsigned hex",
					() => {
						expect( format.hashHtml( "hello" ) ).toBeWithCase( "05e918d2" );
						expect( format.hashHtml( "" ) ).toBeWithCase( "00000000" );
					}
				);

				var fixtureDir = expandPath( "/cbstudioTests/fixtures/block-format" );
				var files = directoryList(
					fixtureDir,
					false,
					"path",
					"*.json",
					"name asc"
				);

				it(
					"finds the fixtures",
					() => {
						expect( files.len() ).toBeGT( 10 );
					}
				);

				for ( var file in files ) {
					var fixture = deserializeJSON( fileRead( file, "utf-8" ) );
					var name = getFileFromPath( file ) & ": " & fixture.description;

					describe(
						name,
						() => {
							it(
								title = "parses",
								data  = { fixture: fixture },
								body  = ( data ) => {
									assertSameBlocks( format.parse( data.fixture.body ), data.fixture.blocks );
								}
							);

							if ( fixture.keyExists( "serialized" ) ) {
								it(
									title = "serializes the parsed blocks like the reference",
									data  = { fixture: fixture },
									body  = ( data ) => {
										var written = format.serialize( data.fixture.blocks );
										assertSameBlocks(
											format.parse( written ),
											format.parse( data.fixture.serialized )
										);
										var hashes = ( body ) => reMatch( """hash"":""[0-9a-f]{8}""", body );
										expect( hashes( written ) ).toBe( hashes( data.fixture.serialized ) );
									}
								);
							}

							it(
								title = "round-trips",
								data  = { fixture: fixture },
								body  = ( data ) => {
									var again = format.parse( format.serialize( data.fixture.blocks ) );
									expect( again.len() ).toBe(
										data
											.fixture
											.blocks
											.len()
									);
									for ( var i = 1; i <= again.len(); i++ ) {
										var expected = data.fixture.blocks[ i ];
										expect( again[ i ].status ).toBeWithCase( "ok" );
										expect( again[ i ].type ).toBeWithCase( expected.type );
										expect( again[ i ].html ).toBeWithCase(
											format.neutralizeMarkers( expected.html )
										);
									}
								}
							);
						}
					);
				}
			}
		);
	}

	/**
	 * Deep comparison where strings must match with case
	 */
	private function assertSameBlocks( required array actual, required array expected ) {
		expect( arguments.actual.len() ).toBe( arguments.expected.len(), "number of blocks" );
		for ( var i = 1; i <= arguments.actual.len(); i++ ) {
			for ( var key in [ "type", "id", "html", "status" ] ) {
				expect( arguments.actual[ i ][ key ] ).toBeWithCase(
					arguments.expected[ i ][ key ],
					"block #i# #key#"
				);
			}
			expect( arguments.actual[ i ].v ).toBe( arguments.expected[ i ].v, "block #i# v" );
			expect(
				sameValue( arguments.actual[ i ].data, arguments.expected[ i ].data )
			).toBeTrue(
				"block #i# data: #serializeJSON( arguments.actual[ i ].data )# vs #serializeJSON(
					arguments.expected[ i ].data
				)#"
			);
		}
	}

	private boolean function sameValue( actual, expected ) {
		if ( isStruct( arguments.expected ) ) {
			if ( !isStruct( arguments.actual ) || arguments.actual.count() != arguments.expected.count() ) {
				return false;
			}
			for ( var key in arguments.expected ) {
				if (
					!arguments.actual.keyExists( key ) ||
						!sameValue( arguments.actual[ key ], arguments.expected[ key ] )
				) {
					return false;
				}
			}
			return true;
		}
		if ( isArray( arguments.expected ) ) {
			if ( !isArray( arguments.actual ) || arguments.actual.len() != arguments.expected.len() ) {
				return false;
			}
			for ( var i = 1; i <= arguments.expected.len(); i++ ) {
				if ( !sameValue( arguments.actual[ i ], arguments.expected[ i ] ) ) {
					return false;
				}
			}
			return true;
		}
		return isSimpleValue( arguments.actual ) && compare( arguments.actual, arguments.expected ) == 0;
	}

}