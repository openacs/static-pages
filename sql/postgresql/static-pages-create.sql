--  packages/static-pages/sql/static-pages-create.sql
--
--  /**
--   *  Data model creation script for static-pages.
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

-- set def off
create table sp_folders (
        folder_id	integer constraint sp_folders_folder_id_pk
                        primary key
                        constraint sp_folders_folder_id_fk
                        references cr_folders,
        parent_id	integer constraint sp_folders_parent_id_fk
                        references sp_folders(folder_id),
        package_id	integer constraint sp_folders_package_id_fk
                        references apm_packages,
	tree_sortkey	varbit
);



comment on table sp_folders is '
        Holds the folder hierarchy, mirroring the structure of the folders in
        the content repository.  Used for navigating through the static
        pages in a hierarchical manner.
';
comment on column sp_folders.folder_id is '
        ID of folder.
';
comment on column sp_folders.parent_id is '
        ID of parent folder; null if this is the root folder.
';
comment on column sp_folders.package_id is '
        Keep track of the package that owns the folder.  This is used
        to avoid conflicts if more than one package is using Static
        Pages functions.
';

-- These indices are needed because the columns have foreign key constraints.
--
create index sp_folders_parent_id_idx on sp_folders(parent_id);
create index sp_folders_package_id_idx on sp_folders(package_id);

--tree_sortkey index DaveB
create index sp_folders_tree_skey_idx on sp_folders (tree_sortkey);

create function sp_folders_get_tree_sortkey(integer) returns varbit as '
declare
  p_folder_id    alias for $1;
begin
  return tree_sortkey from sp_folders where folder_id = p_folder_id;
end;' language 'plpgsql';

-- tree_sortkey triggers DaveB

create function sp_folders_insert_tr () returns opaque as '
declare
        v_parent_sk     varbit default null;
        v_max_value     integer;
begin
	if new.parent_id is null then
            select max(tree_leaf_key_to_int(tree_sortkey)) into v_max_value
              from sp_folders
             where parent_id is null;
	else
	  select max(tree_leaf_key_to_int(tree_sortkey)) into v_max_value 
          from sp_folders 
          where parent_id = new.parent_id;

          select tree_sortkey into v_parent_sk 
          from sp_folders 
          where folder_id = new.parent_id;
	end if;
        new.tree_sortkey := tree_next_key(v_parent_sk, v_max_value);
        return new;
end;' language 'plpgsql';

create trigger sp_folders_insert_tr before insert 
on sp_folders for each row 
execute procedure sp_folders_insert_tr ();

create function sp_folders_update_tr () returns opaque as '
declare
        v_parent_sk     varbit default null;
        v_max_value     integer;
        v_rec           record;
        clr_keys_p      boolean default ''t'';
begin
        if new.folder_id = old.folder_id and 
           ((new.parent_id = old.parent_id) or 
            (new.parent_id is null and old.parent_id is null)) then

           return new;

        end if;

        for v_rec in select folder_id, parent_id
                       from sp_folders 
                      where tree_sortkey between new.tree_sortkey and tree_right(new.tree_sortkey)
                   order by tree_sortkey
        LOOP
            if clr_keys_p then
               update sp_folders set tree_sortkey = null
               where tree_sortkey between new.tree_sortkey and tree_right(new.tree_sortkey);
               clr_keys_p := ''f'';
            end if;
            
            select max(tree_leaf_key_to_int(tree_sortkey)) into v_max_value
              from sp_folders 
              where parent_id = v_rec.parent_id;

            select tree_sortkey into v_parent_sk 
              from sp_folders 
             where folder_id = v_rec.parent_id

            update sp_folders 
               set tree_sortkey = tree_next_key(v_parent_sk, v_max_value)
             where folder_id = v_rec.folder_id;

        end LOOP;

        return new;

end;' language 'plpgsql';

create trigger sp_folders_update_tr before update 
on sp_folders for each row 
execute procedure sp_folders_update_tr ();

-- end of tree_sortkey triggers DaveB


-- The title and content of each page will go into cr_revisions.  Here
-- we record the filename.
--
create table static_pages (
        static_page_id	integer constraint static_pgs_static_pg_id_fk
                        references cr_items
                        constraint static_pgs_static_pg_pk
                        primary key,
        filename	varchar(500),
        folder_id	integer constraint static_pgs_folder_id_fk
                        references sp_folders,
        show_comments_p	boolean
                        default 't'
                        not null,
	mtime		integer
);
comment on table static_pages is '
        Extends the cr_items table to hold information on static pages.
';
comment on column static_pages.filename is '
        The full path of the file (e.g. /web/my_site/www/books/index.html).
';
comment on column static_pages.folder_id is '
        ID of folder containing page.
';
comment on column static_pages.show_comments_p is '
        Are comments shown on the page, or is the user simply offered a link
        to view the comments?
';
comment on column static_pages.mtime is '
	Last modification time of file as reported by [file mtime]
';

-- Another foreign key column:
--
create index static_pages_folder_id_idx on static_pages(folder_id);

-- We need an index on the filename column since the page handler
-- queries against it to get page information.
--
create index static_pages_filename_idx on static_pages(filename);

-- These holds the ids of files and folders that are actually in the
-- filesystem.  Once it is updated, we can delete all static_pages
-- and sp_folders that don't have rows in sp_extant_*.
--
create table sp_extant_files (
        session_id	integer not null,
        static_page_id	integer not null
                        constraint sp_extant_files_file_id_fk
                        references static_pages
                        on delete cascade
);
comment on table sp_extant_files is '
        Holds the ids of files that are actually in the filesystem.  Once it is
        updated, we can delete all static_pages that don''t have a row in
        sp_extant_files.
';
comment on column sp_extant_files.session_id is '
        Each syncing session has an identifier in order to avoid conflicts that would
        arise if two admins sync simultaneously.
';
comment on column sp_extant_files.static_page_id is '
        The static_page_id for a file in the filesystem.
';

create table sp_extant_folders (
        session_id	integer not null,
        folder_id	integer not null
                        constraint sp_extant_folders_file_id_fk
                        references sp_folders
                        on delete cascade
);
comment on table sp_extant_folders is '
        Holds the ids of folders that are actually in the filesystem.  Once it is
        updated, we can delete all sp_folders that don''t have a row in
        sp_extant_folders.
';
comment on column sp_extant_folders.session_id is '
        Each syncing session has an identifier in order to avoid conflicts that would
        arise if two admins sync simultaneously.
';
comment on column sp_extant_folders.folder_id is '
        The folder_id for a folder in the filesystem.
';

-- Here's where we get our session_ids:

create sequence sp_session_id_sequence;
create view sp_session_id_seq as select nextval('sp_session_id_sequence') as nextval;


-- this also creates the acs_object type
        select content_type__create_type (
		'static_page',		-- content_type 
		'content_revision',	-- supertype    
		'Static Page',		-- pretty_name  
		'Static Pages',		-- pretty_plural
		'static_pages',		-- table_name   
		'static_page_id',	-- id_column    
		null			-- name_method  
        );

        select content_type__create_attribute (
		'static_page',		-- content_type  
		'filename',		-- attribute_name
		'text',			-- datatype      
		'Filename',		-- pretty_name   
		'Filenames',		-- pretty_plural 
		null,			-- sort_order    
		null,			-- default_value 
		'varchar(500)'		-- column_spec   
        );


\i static-page-pb.sql
\i static-pages-sc-create.sql
