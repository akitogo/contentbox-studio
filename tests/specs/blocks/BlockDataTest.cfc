/**
 * models/blocks/BlockData.cfc: field definitions and data normalization
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"Block data",
			() => {
				beforeEach(
					() => {
						blockData = getInstance( "BlockData@contentbox-studio" );
					}
				);

				describe(
					"field definitions",
					() => {
						it(
							"completes labels and defaults",
							() => {
								var fields = blockData.normalizeFields(
									[
										{ "name": "title", "type": "text" },
										{
											"name"  : "items",
											"type"  : "list",
											"fields": [ { "name": "x", "type": "number" } ]
										}
									],
									"test"
								);
								expect( fields[ 1 ].label ).toBe( "title" );
								expect( fields[ 1 ].default ).toBe( "" );
								expect( fields[ 1 ].required ).toBeFalse();
								expect( fields[ 2 ].fields[ 1 ].type ).toBe( "number" );
							}
						);

						it(
							"rejects unknown types, duplicate names and selects without options",
							() => {
								expect(
									() => blockData.normalizeFields( [ { "name": "x", "type": "nope" } ], "test" )
								).toThrow( "BlockDefinition.InvalidField" );
								expect(
									() => blockData.normalizeFields(
										[ { "name": "x", "type": "text" }, { "name": "x", "type": "text" } ],
										"test"
									)
								).toThrow( "BlockDefinition.InvalidField" );
								expect(
									() => blockData.normalizeFields( [ { "name": "x", "type": "select" } ], "test" )
								).toThrow( "BlockDefinition.InvalidField" );
								expect(
									() => blockData.normalizeFields( [ { "name": "1x", "type": "text" } ], "test" )
								).toThrow( "BlockDefinition.InvalidField" );
							}
						);
					}
				);

				describe(
					"data",
					() => {
						beforeEach(
							() => {
								fields = blockData.normalizeFields(
									[
										{
											"name"     : "title",
											"type"     : "text",
											"required" : true,
											"maxLength": 10
										},
										{ "name": "body", "type": "textarea" },
										{
											"name"   : "level",
											"type"   : "select",
											"default": "2",
											"options": [ "2", "3" ]
										},
										{
											"name": "count",
											"type": "number",
											"min" : 1,
											"max" : 5
										},
										{ "name": "flag", "type": "boolean" },
										{ "name": "link", "type": "link" },
										{ "name": "image", "type": "image" },
										{ "name": "images", "type": "images", "maxItems": 2 },
										{ "name": "store", "type": "contentStore" },
										{
											"name"  : "items",
											"type"  : "list",
											"fields": [ { "name": "label", "type": "text", "required": true } ]
										}
									],
									"test"
								);
							}
						);

						it(
							"keeps exactly the defined fields, with defaults for missing ones",
							() => {
								var result = blockData.normalize( fields, { "title": "Hi", "unknown": "dropped" } );
								expect( result.data ).notToHaveKey( "unknown" );
								expect( result.data.level ).toBe( "2" );
								expect( result.data.flag ).toBeFalse();
								expect( result.data.link ).toBe( { "href": "", "target": "" } );
								expect( result.data.images ).toBe( [] );
								expect( result.errors ).toBeEmpty();
							}
						);

						it(
							"reports required, too long, out of range and invalid choices",
							() => {
								var result = blockData.normalize( fields, { "title": "", "level": "9", "count": 7 } );
								var messages = result.errors.map( ( error ) => error.field );
								expect( messages ).toInclude( "title" );
								expect( messages ).toInclude( "level" );
								expect( messages ).toInclude( "count" );
								expect( result.data.level ).toBe( "2" );

								var tooLong = blockData.normalize( fields, { "title": "far too long title" } );
								expect( tooLong.errors[ 1 ].field ).toBe( "title" );
							}
						);

						it(
							"makes single-line text single-line and normalizes line breaks",
							() => {
								var result = blockData.normalize(
									fields,
									{
										"title": "a#chr( 13 )##chr( 10 )#b",
										"body" : "x#chr( 13 )##chr( 10 )#y#chr( 13 )#z"
									}
								);
								expect( result.data.title ).toBeWithCase( "a b" );
								expect( result.data.body ).toBeWithCase( "x#chr( 10 )#y#chr( 10 )#z" );
							}
						);

						it(
							"refuses unsafe links and image URLs",
							() => {
								var result = blockData.normalize(
									fields,
									{
										"title": "x",
										"link" : { "href": "javascript:alert(1)", "target": "_top" },
										"image": { "src": "data:image/svg+xml,x", "alt": "a" }
									}
								);
								expect( result.data.link ).toBe( { "href": "", "target": "" } );
								expect(
									result
										.data
										.image
										.src
								).toBe( "" );
								expect( result.errors.map( ( error ) => error.field ) ).toBe( [ "link", "image" ] );
							}
						);

						it(
							"normalizes images and list items, with item paths in errors",
							() => {
								var result = blockData.normalize(
									fields,
									{
										"title" : "x",
										"images": [
											{
												"src"   : "/a.jpg",
												"alt"   : "A",
												"width" : "800",
												"onload": "x"
											},
											{ "src": "" },
											"/b.jpg",
											"/c.jpg"
										],
										"items": [ { "label": "one" }, { "label": "" } ],
										"store": "footer-cta"
									}
								);
								expect(
									result
										.data
										.images
										.len()
								).toBe( 3 );
								expect( result.data.images[ 1 ] ).toBe( { "src": "/a.jpg", "alt": "A", "width": 800 } );
								expect( result.data.items[ 2 ].label ).toBe( "" );
								var paths = result.errors.map( ( error ) => error.field );
								expect( paths ).toInclude( "images" );
								expect( paths ).toInclude( "items[2].label" );
								expect( result.data.store ).toBe( "footer-cta" );
							}
						);

						it(
							"refuses content store slugs that are not slugs",
							() => {
								var result = blockData.normalize(
									fields,
									{ "title": "x", "store": "x"" onclick=""y" }
								);
								expect( result.data.store ).toBe( "" );
								expect( result.errors[ 1 ].field ).toBe( "store" );
							}
						);
					}
				);
			}
		);
	}

}