# packages/static-pages/www/admin/index.tcl
ad_page_contract {
    Main admin page for static-pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-01-22
    @cvs-id $Id$
} {
} -properties {
    title:onevalue
    context:onevalue
    n_static_pages:onevalue
    are:onevalue
    pages:onevalue
}

set root_folder_id [sp_root_folder_id [ad_conn package_id]]

db_1row count_static_pages {
    select count(*) as n_static_pages from static_pages
    where folder_id in (
	select folder_id from sp_folders
	start with folder_id = :root_folder_id
	connect by parent_id = prior folder_id
    )
}

if { $n_static_pages == 1 } {
    set are "is"
    set pages "page"
} else {
    set are "are"
    set pages "pages"
}

set title "Static Pages Administration"

set context [list $title]
