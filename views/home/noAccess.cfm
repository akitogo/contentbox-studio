<cfoutput><!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="robots" content="noindex, nofollow">
	<title>No access to ContentBox Studio</title>
	<style>
		body { font-family: system-ui, sans-serif; max-width: 36rem; margin: 4rem auto; padding: 0 1rem; line-height: 1.5; }
	</style>
</head>
<body>
	<h1>No access to ContentBox Studio</h1>
	<p>
		You are logged in as #encodeForHTML( prc.author.getFullName() )#, but Studio needs the
		<code>STUDIO_ACCESS</code> permission. An administrator can grant it to your role or account in the classic admin.
	</p>
	<p><a href="#encodeForHTMLAttribute( prc.adminUrl )#">Back to the classic admin</a></p>
</body>
</html>
</cfoutput>
