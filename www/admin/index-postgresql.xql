<?xml version="1.0"?>
<queryset>
	   <rdbms><type>postgresql</type><version>7.1</version></rdbms>
<fullquery name="count_static_pages">      
      <querytext>
      
    select count(*) as n_static_pages from static_pages
    where folder_id in (
	select folder_id from sp_folders 
		where tree_sortkey like ( select tree_sortkey || '%'
		from sp_folders
		where folder_id = :root_folder_id)
    )

      </querytext>
</fullquery>

 
</queryset>
