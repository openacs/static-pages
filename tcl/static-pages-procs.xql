<?xml version="1.0"?>
<queryset>

<fullquery name="sp_sync_cr_with_filesystem_internal.insert_path">
      <querytext>

			insert into sp_extant_folders (session_id,folder_id)
			values (:sync_session_id,:folder_id)

      </querytext>
</fullquery>

<fullquery name="sp_sync_cr_with_filesystem_internal.get_storage_type">
	<querytext>
		select storage_type from cr_items
			where item_id = :static_page_id
	</querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.insert_file">
      <querytext>

		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)

      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.insert_file">
      <querytext>

		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)

      </querytext>
</fullquery>

</queryset>
