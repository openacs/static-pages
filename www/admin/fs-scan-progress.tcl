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
    ns_write "\n<br><code>$path</code>: <i>unchanged</i>"
}
proc sp_new_item { path id } {
    ns_write "\n<br><code>$path</code>: <i>added</i>"
}
proc sp_changed_item { path id } {
    ns_write "\n<br><code>$path</code>: <i>updated</i>"
    # The title may have changed:
    sp_flush_page $id
}

proc sp_error_item { path id msg } {
   ns_write "\n<br>
<br><code>$path</code>: <strong>Error:</strong>
<blockquote>$msg</blockquote>"
}

set title "Filesystem search"
set context_bar [ad_context_bar $title]
#set context_bar [ad_admin_context_bar {index "Static Pages Admin"} $title]


ReturnHeaders
ns_write "<html><head><title>$title</title></head><body bgcolor=white>
<h2>$title</h2>
$context_bar
<hr>
"

set package_id [ad_conn package_id]
set root_folder_id [sp_root_folder_id $package_id]

# TODO: Add the fs_root parameter to the package:
# --atp@piskorski.com, 2002/12/11 18:12 EST
#set fs_root "[acs_root_dir][ad_parameter -package_id $package_id {fs_root}]"
set fs_root "[acs_root_dir]/www"

ns_write "
<p>
[sp_sync_cr_with_filesystem \
	-file_unchanged_proc sp_old_item \
	-file_add_proc sp_new_item \
	-file_change_proc sp_changed_item \
        -file_read_error_proc sp_error_item \
	-folder_add_proc sp_new_item \
	-folder_unchanged_proc sp_old_item \
	$fs_root $root_folder_id]
<p>
"

ns_write "</body></html>\n"
