# packages/static-pages/www/admin/commentability-contain.tcl
ad_page_contract {
    Change commentability status of pages containing a given string.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-21
    @cvs-id $Id$
} {
    change_option
    {contained_string ""}
}


set root_folder_id [sp_root_folder_id [ad_conn package_id]]

switch $change_option {
    "grant_p_1" { sp_change_matching_permissions $root_folder_id $contained_string "grant" }
    "grant_p_0" { sp_change_matching_permissions $root_folder_id $contained_string "revoke" }
    "show_p_1" { sp_change_matching_display $root_folder_id $contained_string "t" }
    "show_p_0" { sp_change_matching_display $root_folder_id $contained_string "f" }
}

ad_returnredirect commentability
