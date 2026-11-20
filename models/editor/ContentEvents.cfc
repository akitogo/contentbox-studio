/**
 * ContentBox's events after content changed, as the classic admin announces them. ContentBox listens to
 * cbadmin_post<Type>Save to clear the rendered content, page wrapper, category count, sitemap and RSS caches (without
 * it the public site keeps showing the old content), to update menu items when a page's address changed, and to send
 * its notifications for new content; other modules can react to Studio's changes too.
 */
component singleton {
	property name="interceptorService" inject="coldbox:interceptorService";

	property name="requestService" inject="coldbox:requestService";

	property name="settingService" inject="settingService@contentbox";

	/**
	 * @content      The saved page, entry or content store item
	 * @isNew        Just created
	 * @originalSlug Its slug before the change (e.g. before a move)
	 */
	void function saved(
		required content,
		boolean isNew       = false,
		string originalSlug = ""
	) {
		// The listeners expect the classic admin's request (e.g. the notification e-mails read prc.cbSettings)
		var prc = variables.requestService.getContext().getPrivateCollection();
		if ( !prc.keyExists( "cbSettings" ) ) {
			prc[ "cbSettings" ] = variables.settingService.getAllSettings();
		}
		variables.interceptorService.announce(
			"cbadmin_post#arguments.content.getContentType()#Save",
			{
				"content"     : arguments.content,
				"isNew"       : arguments.isNew,
				"originalSlug": len( arguments.originalSlug ) ? arguments.originalSlug : arguments.content.getSlug()
			}
		);
	}

}