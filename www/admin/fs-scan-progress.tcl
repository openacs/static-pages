# packages/static-pages/www/admin/fs-scan-progress.tcl
ad_page_contract {
    Scan the file system for static pages.  If there are many
    files, this page takes a long time to load, so we use ns_write
    to display progress information.  fs-scan.tcl is a templated
    version of this page.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-03-09
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
    ns_write "<br><code>$path</code>: <i>unchanged</i>"
}
proc sp_new_item { path id } {
    upvar file_items file_items
    ns_write "<br><code>$path</code>: <i>added</i>"
}
proc sp_changed_item { path id } {
    upvar file_items file_items
    ns_write "<br><code>$path</code>: <i>updated</i>"
    # The title may have changed:
    sp_flush_page $id
}

set title "Filesystem search"
set context_bar [ad_context_bar $title]


ReturnHeaders
ns_write "<html><head><title>$title</title></head><body bgcolor=white>
<h2>$title</h2>
$context_bar
<hr>
Starting scan<br /><br />
"

set root_folder_id [sp_root_folder_id [ad_conn package_id]]

sp_sync_cr_with_filesystem \
	-file_unchanged_proc sp_old_item \
	-file_add_proc sp_new_item \
	-file_change_proc sp_changed_item \
	-folder_add_proc sp_new_item \
	-folder_unchanged_proc sp_old_item \
	"[acs_root_dir]/www" $root_folder_id


ns_write "<p><strong>Finished updating static pages</strong></body></html>\n"
