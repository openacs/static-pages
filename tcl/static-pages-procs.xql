<?xml version="1.0"?>
<queryset>

<fullquery name="sp_sync_cr_with_filesystem.get_folder_id">      
      <querytext>
      
			select coalesce(content_item.get_id(:cumulative_path,:root_folder_id),0)
			from dual
		    
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem.insert_path">      
      <querytext>
      
			insert into sp_extant_folders (session_id,folder_id)
			values (:sync_session_id,:folder_id)
		    
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem.check_db_for_page">      
      <querytext>
      
		select static_page_id from static_pages
		where filename = :fs_filename
	    
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem.get_db_page">      
      <querytext>
      
		    select content as file_from_db from cr_revisions
		    where revision_id = content_item.get_live_revision(:static_page_id)
		
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem.insert_file">      
      <querytext>
      
		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)
		
      </querytext>
</fullquery>

 
<fullquery name="sp_sync_cr_with_filesystem.insert_file">      
      <querytext>
      
		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)
		
      </querytext>
</fullquery>

 
<fullquery name="sp_change_matching_display.matching_static_page">      
      <querytext>
      
	select static_page_id from static_pages
	     where folder_id in (
		     select folder_id from sp_folders
		     start with folder_id = :root_folder_id
		     connect by parent_id = prior folder_id)
	     and filename like '%${contained_string}%'
    
      </querytext>
</fullquery>

 
<fullquery name="sp_change_matching_display.show_or_summarize_comments_matching">      
      <querytext>
      
	    update static_pages set show_comments_p = :show_full_comments_p 
                where static_page_id in (
		    select static_page_id from static_pages
		    where folder_id in (
			    select folder_id from sp_folders
			    start with folder_id = :root_folder_id
			    connect by parent_id = prior folder_id)
		    and filename like '%${contained_string}%'
	        )
    
      </querytext>
</fullquery>

 
<fullquery name="sp_flush_page.get_page_info">      
      <querytext>
      sp_get_page_info_query $page_id
      </querytext>
</fullquery>

 
<fullquery name="sp_flush_page.get_page_info">      
      <querytext>
      sp_get_page_info_query $page_id
      </querytext>
</fullquery>

 
</queryset>
