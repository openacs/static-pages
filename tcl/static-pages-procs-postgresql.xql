<?xml version="1.0"?>

<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="sp_sync_cr_with_filesystem.get_db_page">
      <querytext>

		    select content as file_from_db from cr_revisions
		    where revision_id = content_item__get_live_revision(:static_page_id)

      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem.get_folder_id">
      <querytext>

        select coalesce(content_item__get_id(:cumulative_path,:root_folder_id),0)

      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem.create_new_folder">
      <querytext>
                select static_page__new_folder (
                        :directory,             -- name
                        :directory,             -- label
                        :parent_folder_id,      -- parent_id
                        'Static pages folder'   -- description
                );
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem.update_db_file">      
      <querytext>

		update cr_revisions set content = :file
		where revision_id = content_item__get_live_revisions(:static_page_id)
   
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem.do_sp_new">      
      <querytext>
                select static_page__new(
                        :parent_folder_id,       -- folder_id
                        :file,                  -- filename
                        :page_title            -- title

                );
      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem.insert_file_contents">
      <querytext>

		update cr_revisions set content = :file
		where revision_id = content_item__get_live_revisions(:static_page_id)


      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem.delete_old_files">
      <querytext>
	begin
	perform static_page__delete_stale_items(:sync_session_id,:package_id);
--	 delete from sp_extant_folders where session_id = :sync_session_id;
--
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
		    select static_page_id from static_pages
		    where folder_id in (
			select folder_id from sp_folders where
			 tree_sortkey like ( select tree_sortkey || '%'
				from sp_folders
				where folder_id = :root_folder_id)
							)
		    and filename like '%${contained_string}%'
	        )

      </querytext>
</fullquery>


<fullquery name="sp_change_matching_permissions.grant_or_revoke_matching_permissions">
	<querytext>
	    begin

		for file_row in (
		    select static_page_id from static_pages
		    where folder_id in (
			select folder_id from sp_folders where
			 tree_sortkey like ( select tree_sortkey || '%'
				from sp_folders
				where folder_id = :root_folder_id)
   				) and
			filename like '%${contained_string%'}
		) loop

		    PERFORM acs_permission__${grant_or_revoke}_permission(
			    file_row.static_page_id,
			    acs__magic_object_id('the_public'),
			    'general_comments_create'
		    );
	    end loop;
	    end;

	</querytext>
</fullquery>

<fullquery name="sp_change_matching_display.matching_static_page">
      <querytext>

	select static_page_id from static_pages
	     where folder_id in (
		     select folder_id from sp_folders
		     where tree_sortkey like
			(select tree_sortkey ||'%' from sp_folders
				where folder_id = :root_folder_id)
			) and filename like '%${contained_string}%'

      </querytext>
</fullquery>

<fullquery name="sp_get_page_info_query.get_page_info">
	<querytext>
select '{'||content_item__get_title(:page_id)||'} '||CASE WHEN show_comments_p='t' then '1' else '0' END from static_pages where static_page_id = :page_id
	</querytext>
</fullquery>

<fullquery name="sp_flush_page.get_page_info">
      <querytext>
select '{'||content_item__get_title(:page_id)||'} '||CASE WHEN show_comments_p='t' then '1' else '0' END from static_pages where static_page_id = :page_id
      </querytext>
</fullquery>


</queryset>
