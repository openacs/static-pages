<?xml version="1.0"?>
<queryset>
	<rdbms><type>oracle</type><version>8.1.6</version></rdbms>
<fullquery name="count_static_pages">      
      <querytext>
      
    select count(*) as n_static_pages from static_pages
    where folder_id in (
	select folder_id from sp_folders
	start with folder_id = :root_folder_id
	connect by parent_id = prior folder_id
    )

      </querytext>
</fullquery>

 
</queryset>
