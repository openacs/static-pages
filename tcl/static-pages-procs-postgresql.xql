<?xml version="1.0"?>

<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="sp_sync_cr_with_filesystem_internal.get_db_page">
      <querytext>

		    select content as file_from_db from cr_revisions
		    where revision_id = content_item__get_live_revision(:static_page_id)

      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.get_folder_id">
      <querytext>

        select coalesce((select item_id from cr_items where name=:cumulative_path),0)

      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.create_new_folder">
      <querytext>
                select static_page__new_folder (
			NULL, 			-- folder_id	
			:cumulative_path,       -- name
                        :cumulative_path,       -- label
			'Static pages folder',  -- description
			:parent_folder_id,      -- parent_id
			current_timestamp,	-- creation_date
			NULL,			-- creation_user
			NULL,			-- creation_ip
			NULL			-- context_id
                                      );
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem_internal.update_db_file">      
      <querytext>
		update cr_revisions set content = :sp_filename
		where revision_id = content_item__get_live_revision(:static_page_id)
   
      </querytext>
</fullquery>

<fullquery name="sp_sync_cr_with_filesystem_internal.check_db_for_page">
      <querytext>

		select static_page_id, mtime as mtime_from_db from static_pages
		where filename = :sp_filename

      </querytext>
</fullquery>

<fullquery name="sp_sync_cr_with_filesystem_internal.do_sp_new">      
      <querytext>
select static_page__new(
  :parent_folder_id,  -- folder_id
  :sp_filename,       -- filename
  :page_title,        -- title
  :mtime_from_fs      -- mtime
  ,:mime_type         -- mime_type
);
      </querytext>
</fullquery>

<fullquery name="sp_sync_cr_with_filesystem_internal.insert_file_contents">
      <querytext>
		update cr_revisions set content = :sp_filename
		where revision_id = content_item__get_live_revision(:static_page_id)
      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.delete_old_files">
      <querytext>
	begin
	perform static_page__delete_stale_items(:sync_session_id,:package_id);
	 delete from sp_extant_files where session_id = :sync_session_id;
	return null;
	end;
      </querytext>
</fullquery>


<fullquery name="sp_root_folder_id.get_root_folder_id">
      <querytext>
                select static_page__get_root_folder(:package_id);
      </querytext>
</fullquery>

<fullquery name="sp_change_matching_display.show_or_summarize_comments_matching">
      <querytext>

	    update static_pages set show_comments_p = :show_full_comments_p
                where static_page_id in (
		    select sp.static_page_id
                    from static_pages sp, sp_folders s1, sp_folders s2
		    where sp.folder_id = s1.folder_id
                      and s2.folder_id = :root_folder_id
                      and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
		      and sp.filename like '%${contained_string}%'
	        )

      </querytext>
</fullquery>


<fullquery name="sp_change_matching_permissions.grant_or_revoke_matching_permissions">
	<querytext>
	declare file_row RECORD;
	begin
	
		for file_row in 
		    select sp.static_page_id
                    from static_pages sp, sp_folders s1, sp_folders s2
		    where sp.folder_id = s1.folder_id
                      and s2.folder_id = :root_folder_id
                      and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
		      and sp.filename like '%${contained_string}%'
		loop

		    PERFORM acs_permission__${grant_or_revoke}_permission(
			    file_row.static_page_id,
			    acs__magic_object_id('the_public'),
			    'general_comments_create'
		    );
	    end loop;
return NULL;
end;

	</querytext>
</fullquery>

<fullquery name="sp_change_matching_display.matching_static_page">
      <querytext>

	select sp.static_page_id
        from static_pages sp, sp_folders s1, sp_folders s2
        where sp.folder_id = s1.folder_id
          and s2.folder_id = :root_folder_id
          and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
	  and sp.filename like '%${contained_string}%'

      </querytext>
</fullquery>

<fullquery name="sp_get_page_info_query.get_page_info">
	<querytext>
select '{' || content_item__get_title(:page_id) || '} ' || CASE WHEN show_comments_p=TRUE then '1' else '0' END from static_pages where static_page_id = :page_id
	</querytext>
</fullquery>


<fullquery name="sp_get_page_id.page_and_package_ids">
<querytext>
select sp.static_page_id, f.package_id
from static_pages sp, sp_folders f
where sp.filename = :filename
and sp.folder_id = f.folder_id
-- Only want pages from the Static Pages package.
and f.package_id in (
  select package_id  from apm_packages
  where package_key = :package_key )
-- If the same page is in more than one instance of
-- Static Pages for some reason, we only want one of
-- them, and we don't care which.
-- Oracle
--and rownum <= 1
-- PostgreSQL
limit 1
</querytext>
</fullquery>


<fullquery name="sp_package_url.get_mount_point">
<querytext>
select site_node__url(min(node_id)) as url
from site_nodes
where object_id = :package_id
</querytext>
</fullquery>


</queryset>
