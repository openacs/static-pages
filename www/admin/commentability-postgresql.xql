<?xml version="1.0"?>
<queryset>
	   <rdbms><type>postgresql</type><version>7.1</version></rdbms>
<fullquery name="select_static_page">      
      <querytext>

	select spf.folder_id,
case when spf.folder_id = :root_folder_id then '[acs_root_dir]/www/' else 
	content_item__get_title(spf.folder.id)||'/' end as folder_name,
		static_page__five_n_spaces(lev) as spaces,
		static_page_id,
                substr(filename,instr(filename,'/',-1)+1) as filename,
case when p_file.grantee_id = NULL then 'not commentable' else 'commentable' end as file_permission,

case when show_comments_p = 't' then 'comments displayed' else 'comments summarized' end as display_policy,

case when p_folder.grantee_id = NULL then 'children not commentable' else 'children commentable' end as folder_permission

from ((static_pages sp RIGHT OUTER JOIN
   (select tree_level(folder_id) as lev from 
 	(select folder_id from sp_folders 
		where tree_sortkey like ( select tree_sortkey || '%'
		from sp_folders
		where folder_id = :root_folder_id)
	)
   )
 LEFT OUTER JOIN
acs_permissions p_file ON 
 	(p_file.grantee_id = acs.magic_object_id('the_public') and
	 p_file.privilege = 'general_comments_create' and
	 p_file.object_id = sp.static_page_id)

 LEFT OUTER JOIN
acs_permissions p_folder ON
	(p_folder.grantee_id = acs.magic_object_id('the_public') and 
	 p_folder.privilege = 'general_comments_create' and
         p_folder.object_id = spf.folder_id)

      </querytext>
</fullquery>

 
</queryset>
