/**
 * Base for all Studio API handlers. RestHandler provides the JSON responses, including
 * onAuthenticationFailure (401) and onAuthorizationFailure (403) used by the module's firewall.
 */
component extends="coldbox.system.RestHandler" {

}