<?xml version="1.0"?>
<queryset>
	   <rdbms><type>postgresql</type><version>7.1</version></rdbms>
<fullquery name="count_static_pages">      
      <querytext>
      
    select count(*) as n_static_pages
    from static_pages sp, sp_folders s1, sp_folders s2
    where sp.folder_id = s1.folder_id
      and s2.folder_id = :root_folder_id
      and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)

      </querytext>
</fullquery>

 
</queryset>
