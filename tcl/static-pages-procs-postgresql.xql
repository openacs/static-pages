<?xml version="1.0"?>

<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="sp_sync_cr_with_filesystem.create_new_folder">      
      <querytext>
      FIX ME PLSQL 
			    begin
				    :1 := static_page.new_folder (
					    name	=> :directory,
					    label	=> :directory,
					    parent_id	=> :parent_folder_id,
					    description	=> 'Static pages folder'
				    );
			    end;
			
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
      FIX ME PLSQL 
		    begin
			:1 := static_page.new(
				  filename => :file,
				  title => :page_title,
				  folder_id => :parent_folder_id
			      );
		    end;
		
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
      FIX ME PLSQL 
	begin
	    static_page.delete_stale_items(:sync_session_id,:package_id);

	    delete from sp_extant_folders where session_id = :sync_session_id;
	    delete from sp_extant_files where session_id = :sync_session_id;
	end;
    
      </querytext>
</fullquery>

 
<fullquery name="sp_root_folder_id.get_root_folder_id">      
      <querytext>
      FIX ME PLSQL 
	begin
	    :1 := static_page.get_root_folder(:package_id);
	end;
    
      </querytext>
</fullquery>

 
<fullquery name="sp_change_matching_permissions.grant_or_revoke_matching_permissions">      
      <querytext>
      FIX ME PLSQL 
	    begin
	    for file_row in (
		    select static_page_id from static_pages
		    where folder_id in (
			    select folder_id from sp_folders
			    start with folder_id = :root_folder_id
			    connect by parent_id = prior folder_id)
		    and filename like '%${contained_string}%'
	    ) loop
		    acs_permission.${grant_or_revoke}_permission(
			    object_id => file_row.static_page_id,
			    grantee_id => acs.magic_object_id('the_public'),
			    privilege => 'general_comments_create'
		    );
	    end loop;
	    end;
    
      </querytext>
</fullquery>

 
</queryset>
