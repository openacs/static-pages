# packages/static-pages/www/admin/display-policy-toggle.tcl
ad_page_contract {
    Toggle whether or not comment contents are displayed.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-23
    @cvs-id $Id$
} {
    item_id:integer
}

db_dml toggle_display_policy {
    update static_pages
        set show_comments_p = decode(show_comments_p,'t','f','t')
        where static_page_id = :item_id
}

sp_flush_page $item_id

ad_returnredirect commentability
