<!--- Included by interceptors/ClassicAdmin.cfc into the classic content editor; local.studioLink is set (escaped) there --->
<cfoutput>
<div class="alert alert-info" id="cbstudio-notice" role="status">
	<strong>This content is built with blocks in ContentBox Studio.</strong>
	Edit the content in Studio. Here the body is read-only; title, slug, SEO, categories and publishing can still be changed.
	<a class="btn btn-primary btn-sm" href="#local.studioLink#" style="margin-left: 8px">Open in Studio</a>
</div>
<script>
( function(){
	var notice = document.getElementById( "cbstudio-notice" );
	var body = document.getElementById( "content" );
	// Show the notice above the body editor
	if ( notice && body && body.parentNode ) {
		body.parentNode.insertBefore( notice, body );
	}
	if ( body ) {
		body.readOnly = true;
	}
	// CKEditor: lock only the body editor, not the excerpt
	function lock( editor ){
		if ( editor && editor.name === "content" ) {
			editor.setReadOnly( true );
		}
	}
	if ( window.CKEDITOR ) {
		CKEDITOR.on( "instanceReady", function( event ){ lock( event.editor ); } );
		if ( CKEDITOR.instances.content && CKEDITOR.instances.content.status === "ready" ) {
			lock( CKEDITOR.instances.content );
		}
	}
} )();
</script>
</cfoutput>
