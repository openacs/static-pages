# packages/static-pages/www/page-visit.tcl
ad_page_contract {
    Redirect to the indicated page_id.  This page is used by
    site-wide-search.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-03-05
    @cvs-id $Id$
} {
    page_id:integer
}

if { ![db_0or1row sp_path { select filename from static_pages where static_page_id = :page_id }] } {
    ad_return_error "Page not found" "The page requested could not be found."
}

# The filename must begin "[acs_root_dir]/www" to be valid.  These leading
# characters will then be stripped off to produce the URL.
# DaveB: not anymore! We chop off that part and just stuff the relative
# path in the database to allow leaving the static-pages in the filesystem
#
#if { [string first "[acs_root_dir]/www" $filename] != 0 } {
#    ad_return_error "Error in filename" "This page has an invalid filename."
#}


ad_returnredirect [string range $filename [string length "[acs_root_dir]/www"] end]

