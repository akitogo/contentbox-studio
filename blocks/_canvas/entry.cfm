<!---
	Studio's default header of a blog entry in the editor canvas (models/editor/CanvasHeader.cfc). Themes replace it with
	their own blocks/_canvas/entry.cfm, matching what their entry view shows above the content.
--->
<cfoutput><header class="cbs-entry-header">
	<h1 class="cbs-entry-title">#args.studio.esc( args.data.title )#</h1>
	<p class="cbs-entry-meta">#args.studio.esc( args.data.date )#<cfif len( args.data.author )> &middot; #args.studio.esc( args.data.author )#</cfif><cfif arrayLen( args.data.categories )> &middot; #args.studio.esc( arrayToList( args.data.categories, ", " ) )#</cfif></p>
	<cfif len( args.data.image.src )><img class="cbs-entry-image" src="#args.studio.src( args.data.image.src )#" alt=""></cfif>
</header></cfoutput>
