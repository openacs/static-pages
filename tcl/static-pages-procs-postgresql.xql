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
      FIX ME LOB 
			update cr_revisions set content = empty_blob()
			where revision_id = content_item.get_live_revision(:static_page_id)
			returning content into :1
		    
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
      FIX ME LOB
		    update cr_revisions set content = empty_blob()
		    where revision_id = content_item.get_live_revision(:static_page_id)
		    returning content into :1

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


<fullquery name="sp_change_matching_permissions.grant_or_revoke_matching_permissions">
      <querytext>
FIX ME  provisional thought
create function inline__0()
returns integer as '
        declare
                v_file_row    static_pages.static_page_id%TYPE;
        begin
	    for v_file_row in (
		    select static_page_id from static_pages
		    where folder_id in (
			    select folder_id from sp_folders
			    start with folder_id = :root_folder_id
			    connect by parent_id = prior folder_id)
		    and filename like '%${contained_string}%'
	    ) loop
		    acs_permission__${grant_or_revoke}_permission(
			    file_row.static_page_id,                    -- object_id
			    acs__magic_object_id(''the_public''),       -- grantee_id
			    ''general_comments_create''                 -- privilege
		    );
	    end loop;
            return 0;
end;' language 'plpgsql';

select inline__0();

drop function inline__0();
      </querytext>
</fullquery>


</queryset>
