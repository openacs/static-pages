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
		where filename = :sp_filename

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

</queryset>
