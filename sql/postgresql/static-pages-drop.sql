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
create function inline__0()
returns integer as '
declare
        v_root_folder_row RECORD;
begin
	for v_root_folder_row in 
		select folder_id from sp_folders where parent_id is null
	 loop
		perform static_page__delete_folder(v_root_folder_row.folder_id);
	end loop;
        return 0;
end;' language 'plpgsql';

select inline__0();

drop function inline__0();



-- Delete content type 'static_page' and its attributes.

select content_type__drop_type (
            'static_page',     -- content_type
              't',              -- drop_children_p
               'f'              -- drop_table_p
);



select drop_package('static_page');

drop view sp_session_id_seq;
drop sequence sp_session_id_sequence;

drop table sp_extant_files;
drop table sp_extant_folders;

drop index static_pages_filename_idx;
drop table static_pages;

drop index sp_folders_parent_id_idx;
drop index sp_folders_package_id_idx;

drop trigger sp_folders_insert_tr on sp_folders;
drop trigger sp_folders_update_tr on sp_folders;
drop function sp_folders_insert_tr();
drop function sp_folders_update_tr();
drop function sp_folders_get_tree_sortkey(int);
drop table sp_folders;

\i static-pages-sc-drop.sql
