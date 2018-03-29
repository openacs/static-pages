# packages/static-pages/www/admin/commentability.tcl
ad_page_contract {
    Adjust permissions of static pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-20
    @cvs-id $Id$
} {
} -properties {
    title:onevalue
    context:onevalue
    acs_root:onevalue
    dir_tree:multirow
}

set title "Commentability designation"
set context [list $title]
set acs_root [acs_root_dir]

set root_folder_id [sp_root_folder_id [ad_conn package_id]]

# Select the directory tree.
# This selects each descendent folder (spf), outer joined with
# static_pages to get any pages that happen to be in the folder.
# The folder_id is joined against acs_permissions to get the folder
# permissions, and static_page_id is joined against acs_permissions
# to get the file permissions.  Why join with acs_permissions?  Because
# using the permissions API or the all_object_party_privilege_map view
# is too slow.  We know it's safe to use acs_permissions because the
# privilege is granted directly to the_public and it is granted on 
# every folder and file (no inheritance).
#
db_multirow dir_tree select_static_page "
	select spf.folder_id,
		decode(spf.folder_id,:root_folder_id,'[acs_root_dir]/www/',content_item.get_title(spf.folder_id)||'/') as folder_name,
		static_page.five_n_spaces(lev) as spaces,
		static_page_id,
                substr(filename,instr(filename,'/',-1)+1) as filename,
                decode(p_file.grantee_id,NULL,'not commentable','commentable') as file_permission,
		decode(show_comments_p,'t','comments displayed','comments summarized') as display_policy,
                decode(p_folder.grantee_id,NULL,'children not commentable','children commentable') as folder_permission
from static_pages sp,
   (select folder_id,level as lev from sp_folders
    start with folder_id = :root_folder_id
    connect by parent_id = prior folder_id) spf,
   acs_permissions p_file,
   acs_permissions p_folder
where spf.folder_id=sp.folder_id(+)
  and p_file.grantee_id(+) = acs.magic_object_id('the_public')
  and p_file.privilege(+) = 'general_comments_create'
  and p_file.object_id(+) = static_page_id
  and p_folder.grantee_id(+) = acs.magic_object_id('the_public')
  and p_folder.privilege(+) = 'general_comments_create'
  and p_folder.object_id(+) = spf.folder_id
"

ad_return_template
