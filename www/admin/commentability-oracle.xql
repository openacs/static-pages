<?xml version="1.0"?>
<queryset>
	<rdbms><type>oracle</type><version>8.1.6</version></rdbms>
<fullquery name="select_static_page">      
      <querytext>
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

      </querytext>
</fullquery>

 
</queryset>
