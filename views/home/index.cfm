<cfoutput><!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="robots" content="noindex, nofollow">
	<title>ContentBox Studio</title>
	#prc.assetTags.head#
</head>
<body>
	<div id="root"></div>
	<!--- JSON inside a script element: escape "<" so no value can close the element --->
	<script type="application/json" id="cbstudio-config">#serializeJSON( prc.studioConfig ).replace( "<", "<", "all" )#</script>
	#prc.assetTags.body#
</body>
</html>
</cfoutput>
