<?xml version="1.0"?>
<queryset>

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


<fullquery name="sp_serve_html_page.get_page_info">
	<querytext>
select '{'||content_item__get_title(:page_id)||'} '|| (CASE WHEN show_comments_p='t' then '1' else '0' END) from static_pages where static_page_id = :page_id
	</querytext>
</fullquery>

<fullquery name="sp_flush_page.get_page_info">
      <querytext>
select '{'||content_item__get_title(:page_id)||'} '|| (CASE WHEN show_comments_p='t' then '1' else '0' END) from static_pages where static_page_id = :page_id
      </querytext>
</fullquery>


<fullquery name="sp_flush_page.get_page_info">
      <querytext>
select '{'||content_item__get_title(:page_id)||'} '|| (CASE WHEN show_comments_p='t' then '1' else '0' END) from static_pages where static_page_id = :page_id

      </querytext>
</fullquery>


</queryset>
