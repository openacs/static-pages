--  packages/static-pages/sql/static-pages-create.sql
--
--  /**
--   *  Data model drop script for static-pages.
--   *  
--   *  Copyright (C) 2001 ArsDigita Corporation
--   *  Author:  Brandoch Calef (bcalef@arsdigita.com)
--   *  Creation: 2001-02-02
--   *  
--   *  $Id$
--   *  
--   *  This is free software distributed under the terms of the GNU Public
--   *  License.  Full text of the license is available from the GNU Project:
--   *  http://www.fsf.org/copyleft/gpl.html
--   **/

-- Delete all static_page folders and items.
begin
	for root_folder_row in (
		select folder_id from sp_folders where parent_id is null
	) loop
		static_page.delete_folder(root_folder_row.folder_id);
	end loop;
end;
/

-- Delete content type 'static_page' and its attributes.
begin
	content_type.drop_type (
		content_type	=> 'static_page',
		drop_children_p	=> 't',
		drop_table_p	=> 'f'
	);
end;
/

drop package static_page;

drop sequence sp_session_id_seq;
drop table sp_extant_files;
drop table sp_extant_folders;

drop index static_pages_filename_idx;
drop table static_pages;

drop index sp_folders_parent_id_idx;
drop index sp_folders_package_id_idx;
drop table sp_folders;
