# packages/static-pages/www/admin/fs-scan.tcl
ad_page_contract {
    Scan the file system for static pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-01-22
    @cvs-id $Id$
} {
} -properties {
    title:onevalue
    context_bar:onevalue
    file_items:multirow
}

# sp_sync_cr_with_filesystem callbacks to fill file_items with info.
#
proc sp_old_item { path id } {
    upvar file_items file_items
    multirow append file_items $path "unchanged"
}
proc sp_new_item { path id } {
    upvar file_items file_items
    multirow append file_items $path "added"
}
proc sp_changed_item { path id } {
    upvar file_items file_items
    multirow append file_items $path "updated"
    # The title may have changed:
    sp_flush_page $id
}

multirow create file_items path status

set title "Filesystem search"
set context_bar [ad_admin_context_bar {index "Static Pages Admin"} $title]

set root_folder_id [sp_root_folder_id [ad_conn package_id]]

sp_sync_cr_with_filesystem \
	-file_unchanged_proc sp_old_item \
	-file_add_proc sp_new_item \
	-file_change_proc sp_changed_item \
	-folder_add_proc sp_new_item \
	-folder_unchanged_proc sp_old_item \
	"[acs_root_dir]/www" $root_folder_id

ad_return_template
