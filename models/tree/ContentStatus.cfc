/**
 * Status of a page or blog entry as Studio shows it, from its published flag, publish date and expiry date:
 * draft, scheduled, published or expired. Also the same as an HQL condition, for lists filtered by status.
 */
component singleton {
	variables.STATUSES = [ "draft", "scheduled", "published", "expired" ];

	/**
	 * @publishedDate Date or "" (null)
	 * @expireDate    Date or "" (null)
	 *
	 * @return draft, scheduled, published or expired
	 */
	string function of(
		required boolean isPublished,
		any publishedDate = "",
		any expireDate    = "",
		date now          = now()
	) {
		if ( !arguments.isPublished ) {
			return "draft";
		}
		if ( isDate( arguments.expireDate ) && arguments.expireDate <= arguments.now ) {
			return "expired";
		}
		if ( isDate( arguments.publishedDate ) && arguments.publishedDate > arguments.now ) {
			return "scheduled";
		}
		return "published";
	}

	boolean function isStatus( required string status ) {
		return variables.STATUSES.findNoCase( arguments.status ) > 0;
	}

	/**
	 * HQL condition for content with this status, the same rules as of(): uses the parameters :isPublished and :now
	 * (see hqlParams())
	 *
	 * @status A status (see isStatus())
	 * @alias  Alias of the content in the query, e.g. "e"
	 */
	string function hqlCondition( required string status, required string alias ) {
		var a = arguments.alias;
		switch ( lCase( arguments.status ) ) {
			case "draft":
				return "#a#.isPublished = :isPublished";
			case "expired":
				return "#a#.isPublished = :isPublished and #a#.expireDate <= :now";
			case "scheduled":
				return "#a#.isPublished = :isPublished and #a#.publishedDate > :now and (#a#.expireDate is null or #a#.expireDate > :now)";
			default:
				return "#a#.isPublished = :isPublished and (#a#.publishedDate is null or #a#.publishedDate <= :now) and (#a#.expireDate is null or #a#.expireDate > :now)";
		}
	}

	/**
	 * Parameters for hqlCondition() (Hibernate rejects parameters a query does not use)
	 */
	struct function hqlParams( required string status, date now = now() ) {
		if ( lCase( arguments.status ) == "draft" ) {
			return { "isPublished": false };
		}
		return { "isPublished": true, "now": arguments.now };
	}

	/**
	 * Date as yyyy-mm-ddTHH:nn:ss (local time, as ContentBox stores it), "" for no date
	 */
	string function isoDate( any value = "" ) {
		return isDate( arguments.value ?: "" ) ? dateTimeFormat( arguments.value, "yyyy-mm-dd'T'HH:nn:ss" ) : "";
	}

}