<?xml version="1.0"?>

<queryset>
   <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

<fullquery name="sp_sync_cr_with_filesystem_internal.create_new_folder">
      <querytext>

			    begin
				    :1 := static_page.new_folder (
					    name	=> :cumulative_path,
					    label	=> :cumulative_path,
					    parent_id	=> :parent_folder_id,
					    description	=> 'Static pages folder',
					    package_id	=> :package_id
				    );
			    end;

      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.update_db_file">
      <querytext>

			update cr_revisions set content = empty_blob()
			where revision_id = content_item.get_live_revision(:static_page_id)
			returning content into :1

      </querytext>
</fullquery>

<fullquery name="sp_sync_cr_with_filesystem_internal.check_db_for_page">
      <querytext>

		select static_page_id from static_pages
		where filename = :sp_filename

      </querytext>
</fullquery>

<fullquery name="sp_sync_cr_with_filesystem_internal.do_sp_new">
      <querytext>
begin
:1 := static_page.new(
  filename   => :sp_filename
  ,title     => :page_title
  ,folder_id => :parent_folder_id
  ,mime_type => :mime_type
);
end;
      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.insert_file_contents">
      <querytext>
		    update cr_revisions set content = empty_blob()
		    where revision_id = content_item.get_live_revision(:static_page_id)
		    returning content into :1
      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.delete_old_files">
      <querytext>

	begin
	    static_page.delete_stale_items(:sync_session_id,:package_id);

	    delete from sp_extant_folders where session_id = :sync_session_id;
	    delete from sp_extant_files where session_id = :sync_session_id;
	end;

      </querytext>
</fullquery>


<fullquery name="sp_root_folder_id.get_root_folder_id">
      <querytext>

	begin
	    :1 := static_page.get_root_folder(:package_id);
	end;

      </querytext>
</fullquery>

<fullquery name="sp_sync_cr_with_filesystem_internal.get_db_page">
      <querytext>

		    select content as file_from_db from cr_revisions
		    where revision_id = content_item.get_live_revision(:static_page_id)

      </querytext>
</fullquery>


<fullquery name="sp_sync_cr_with_filesystem_internal.get_folder_id">
      <querytext>

        select nvl((select item_id from cr_items where name=:cumulative_path),0)
        from dual

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


<fullquery name="sp_change_matching_permissions.grant_or_revoke_matching_permissions">
      <querytext>

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

<fullquery name="sp_get_page_info_query.get_page_info">
	<querytext>
select '{'||content_item.get_title($page_id)||'} '||decode(show_comments_p,'t',1,0) from static_pages where static_page_id = :page_id

</querytext>
</fullquery>


<fullquery name="sp_get_page_id.page_and_package_ids">
<querytext>
select sp.static_page_id, f.package_id
from static_pages sp, sp_folders f
where sp.filename = :filename
and sp.folder_id = f.folder_id
-- Only want pages from the Static Pages package.
and f.package_id in (
  select package_id  from apm_packages
  where package_key = :package_key )
-- If the same page is in more than one instance of
-- Static Pages for some reason, we only want one of
-- them, and we don't care which.
-- Oracle
and rownum <= 1
-- PostgreSQL
--limit 1
</querytext>
</fullquery>


<fullquery name="sp_package_url.get_mount_point">
<querytext>
select site_node.url(min(node_id)) as url
from site_nodes
where object_id = :package_id
</querytext>
</fullquery>


</queryset>
