/**
 * models/blocks/RichText.cfc and models/blocks/Markup.cfc
 */
component extends="cbstudioTests.resources.StudioBaseTest" {

	function run( testResults, testBox ) {
		describe(
			"Markup",
			() => {
				beforeEach(
					() => {
						markup = getInstance( "Markup@contentbox-studio" );
					}
				);

				it(
					"escapes text and defuses ContentBox's widget and link syntax",
					() => {
						expect(
							markup.esc(
								"<b> & ""q"" 'a' {{{ContentStore slug=""x""}}} page:[about]"
							)
						).toBeWithCase(
							"&lt;b&gt; &amp; &quot;q&quot; &##39;a&##39; &##123;&##123;&##123;ContentStore slug=&quot;x&quot;}}} page:&##91;about]"
						);
					}
				);

				it(
					"allows http, https, mailto, tel, relative URLs, anchors and ContentBox links",
					() => {
						for ( var candidate in [
							"https://example.com/a?b=c",
							"http://x.test",
							"mailto:a@b.test",
							"tel:+4930123",
							"/about",
							"about-us",
							"##top",
							"?page=2",
							"page:[about-us]",
							"root:[assets/a.pdf]"
						] ) {
							expect( markup.safeUrl( candidate ) ).toBeWithCase( candidate, candidate );
						}
					}
				);

				it(
					"refuses script, data and other schemes, also disguised",
					() => {
						for ( var candidate in [
							"javascript:alert(1)",
							" JavaScript:alert(1)",
							"data:text/html,<b>x</b>",
							"vbscript:x",
							"java" & chr( 9 ) & "script:alert(1)",
							"ftp://x"
						] ) {
							expect( markup.safeUrl( candidate ) ).toBe( "", candidate );
						}
					}
				);

				it(
					"encodes spaces in URLs",
					() => {
						expect( markup.safeUrl( "/my page" ) ).toBeWithCase( "/my%20page" );
					}
				);

				it(
					"allows only http, https and relative image URLs",
					() => {
						expect( markup.safeImageUrl( "/__media/a.jpg" ) ).toBeWithCase( "/__media/a.jpg" );
						expect( markup.safeImageUrl( "mailto:a@b.test" ) ).toBe( "" );
						expect( markup.safeImageUrl( "page:[about]" ) ).toBe( "" );
					}
				);

				it(
					"keeps ContentBox links raw in hrefs so ContentBox resolves them",
					() => {
						expect( markup.href( "page:[about]" ) ).toBeWithCase( "page:[about]" );
						expect( markup.href( "/a?x=1&y=2" ) ).toBeWithCase( "/a?x=1&amp;y=2" );
					}
				);
			}
		);

		describe(
			"Rich text",
			() => {
				beforeEach(
					() => {
						richText = getInstance( "RichText@contentbox-studio" );
					}
				);

				it(
					"renders paragraphs, marks and links with escaped text",
					() => {
						var doc = {
							"type"   : "doc",
							"content": [
								{
									"type"   : "paragraph",
									"content": [
										{ "type": "text", "text": "Sea <view> {{{x}}} " },
										{
											"type" : "text",
											"text" : "bold",
											"marks": [ { "type": "bold" }, { "type": "italic" } ]
										},
										{ "type": "text", "text": " and " },
										{
											"type" : "text",
											"text" : "a link",
											"marks": [
												{
													"type" : "link",
													"attrs": { "href": "https://example.com", "target": "_blank" }
												}
											]
										}
									]
								}
							]
						};
						expect( richText.toHTML( doc ) ).toBeWithCase(
							"<p>Sea &lt;view&gt; &##123;&##123;&##123;x}}} <strong><em>bold</em></strong> and <a href=""https://example.com"" target=""_blank"" rel=""noopener noreferrer"">a link</a></p>"
						);
					}
				);

				it(
					"drops unsafe links but keeps their text",
					() => {
						var doc = {
							"type"   : "doc",
							"content": [
								{
									"type"   : "paragraph",
									"content": [
										{
											"type" : "text",
											"text" : "click",
											"marks": [
												{
													"type" : "link",
													"attrs": { "href": "javascript:alert(1)" }
												}
											]
										}
									]
								}
							]
						};
						expect( richText.toHTML( doc ) ).toBeWithCase( "<p>click</p>" );
					}
				);

				it(
					"renders lists, headings, quotes, breaks and rules",
					() => {
						var doc = {
							"type"   : "doc",
							"content": [
								{
									"type"   : "heading",
									"attrs"  : { "level": 3 },
									"content": [ { "type": "text", "text": "H" } ]
								},
								{
									"type"   : "orderedList",
									"attrs"  : { "start": 3 },
									"content": [
										{
											"type"   : "listItem",
											"content": [
												{
													"type"   : "paragraph",
													"content": [ { "type": "text", "text": "one" } ]
												}
											]
										}
									]
								},
								{
									"type"   : "blockquote",
									"content": [
										{
											"type"   : "paragraph",
											"content": [
												{ "type": "text", "text": "q" },
												{ "type": "hardBreak" },
												{ "type": "text", "text": "r" }
											]
										}
									]
								},
								{ "type": "horizontalRule" }
							]
						};
						expect( richText.toHTML( doc ) ).toBeWithCase(
							"<h3>H</h3><ol start=""3""><li><p>one</p></li></ol><blockquote><p>q<br>r</p></blockquote><hr>"
						);
					}
				);

				it(
					"keeps the content of unknown nodes, drops unknown marks and attributes",
					() => {
						var doc = {
							"type"   : "doc",
							"content": [
								{
									"type"   : "customWidget",
									"attrs"  : { "onclick": "x" },
									"content": [
										{
											"type"   : "paragraph",
											"attrs"  : { "style": "color:red" },
											"content": [
												{
													"type" : "text",
													"text" : "kept",
													"marks": [ { "type": "highlight" } ]
												}
											]
										}
									]
								},
								{
									"type"   : "heading",
									"attrs"  : { "level": 9 },
									"content": [ { "type": "text", "text": "level falls back to 2" } ]
								}
							]
						};
						expect( richText.toHTML( doc ) ).toBeWithCase( "<p>kept</p><h2>level falls back to 2</h2>" );
					}
				);

				it(
					"treats anything that is not a document as empty",
					() => {
						expect( richText.toHTML( "<script>alert(1)</script>" ) ).toBe( "" );
						expect(
							richText.isEmpty( { "type": "doc", "content": [ { "type": "paragraph" } ] } )
						).toBeTrue();
						expect(
							richText.isEmpty(
								{
									"type"   : "doc",
									"content": [
										{
											"type"   : "paragraph",
											"content": [ { "type": "text", "text": "x" } ]
										}
									]
								}
							)
						).toBeFalse();
					}
				);
			}
		);
	}

}