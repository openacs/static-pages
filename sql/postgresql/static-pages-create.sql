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
	tree_sortkey	varchar(4000)
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

-- tree_sortkey triggers DaveB

create function sp_folders_insert_tr () returns opaque as '
declare
        v_parent_sk     varchar;
        max_key         varchar;
begin
	 if new.parent_id is null then
            select max(tree_sortkey) into max_key
              from sp_folders
             where parent_id is null;

            v_parent_sk := '''';
	else

	select max(tree_sortkey) into max_key 
          from sp_folders 
         where parent_id = new.parent_id;

        select coalesce(max(tree_sortkey),'''') into v_parent_sk 
          from sp_folders 
         where folder_id = new.parent_id;
	end if;
        new.tree_sortkey := v_parent_sk || ''/'' || tree_next_key(max_key);


        return new;

end;' language 'plpgsql';

create trigger sp_folders_insert_tr before insert 
on sp_folders for each row 
execute procedure sp_folders_insert_tr ();

create function sp_folders_update_tr () returns opaque as '
declare
        v_parent_sk     varchar;
        max_key         varchar;
        v_rec           record;
        clr_keys_p      boolean default ''t'';
begin
        if new.folder_id = old.folder_id and 
           ((new.parent_id = old.parent_id) or 
            (new.parent_id is null and old.parent_id is null)) then

           return new;

        end if;

        for v_rec in select folder_id
                       from sp_folders 
                      where tree_sortkey like new.tree_sortkey || ''%''
                   order by tree_sortkey
        LOOP
            if clr_keys_p then
               update sp_folders set tree_sortkey = null
               where tree_sortkey like new.tree_sortkey || ''%'';
               clr_keys_p := ''f'';
            end if;
            
            select max(tree_sortkey) into max_key
              from sp_folders 
              where parent_id = (select parent_id 
                                   from sp_folders 
                                  where folder_id = v_rec.folder_id);

            select coalesce(max(tree_sortkey),'''') into v_parent_sk 
              from sp_folders 
             where folder_id = (select parent_id
                                   from sp_folders 
                                  where folder_id = v_rec.folder_id);

            update sp_folders 
               set tree_sortkey = v_parent_sk || ''/'' || tree_next_key(max_key)
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
                        not null
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

-- create or replace package body static_page as
create	function static_page__new (
                integer, 	-- static_page_id	in static_pages.static_page_id%TYPE
                         	--               default null,
                integer, 	-- folder_id	in sp_folders.folder_id%TYPE,
                varchar, 	-- filename	in static_pages.filename%TYPE default null,
                varchar, 	-- title	in cr_revisions.title%TYPE default null,
                text,           -- content	in cr_revisions.content%TYPE default null,
                boolean, 	-- show_comments_p	in static_pages.show_comments_p%TYPE default 't',
                timestamp, 	-- creation_date	in acs_objects.creation_date%TYPE
                           	--             default sysdate,
                integer, 	-- creation_user	in acs_objects.creation_user%TYPE
                         	--               default null,
                varchar, 	-- creation_ip	in acs_objects.creation_ip%TYPE
                                --        default null,
                integer 	-- context_id	in acs_objects.context_id%TYPE
                                --        default null
        ) returns integer as '
	declare
                p_static_page_id        alias for $1;
                p_folder_id             alias for $2;
                p_filename              alias for $3;
                p_title                 alias for $4;
                p_content               alias for $5;
                p_show_comments_p       alias for $6;
                p_creation_date         alias for $7;
                p_creation_user         alias for $8;
                p_creation_ip           alias for $9;
                p_context_id            alias for $10;

                v_item_id	        static_pages.static_page_id%TYPE;
                v_permission_row        RECORD;
		v_revision_id		integer;
		v_is_live		boolean default ''t'';
		v_mime_type		cr_revisions.mime_type%TYPE default ''text/html'';
		v_storage_type		cr_items.storage_type%TYPE default ''file'';
        begin
                -- Create content item; this also makes the content revision.
                -- One might be tempted to set the content_type to static_page,
                -- But this would confuse site-wide-search, which expects to
                -- see a content_type of content_revision.
		
                v_item_id := content_item__new(
                        p_static_page_id,               -- item_id
			p_filename,                     -- name		
			p_folder_id,                    -- parent_id
                        p_title,                        -- title
                        p_creation_date,                -- creation_date
                        p_creation_user,                -- creation_user
                        p_context_id,                   -- context_id
                        p_creation_ip,                  -- creation_ip
                        v_is_live,                          -- is_live
                        v_mime_type,                  -- mime_type
			p_content,                       -- text
			v_storage_type,			 -- storage_type
			FALSE,				 -- security_inherit_p
			''STATIC_PAGES'',		-- storage_area_key
			''content_item'',		 -- item subtype
			''static_page''			 -- content_type
                );


                -- We want to be able to have non-commentable folders below
                -- commentable folders.  We can''t do this if we leave security
                -- inheritance enabled.
                --
-- uses overloaded content_item__new and acs_object__new to set
-- security_inherit_p to ''f'' DaveB
--                update acs_objects set security_inherit_p = ''f''
--                        where object_id = v_item_id;

                -- Copy permissions from the parent:
                for v_permission_row in 
                        select grantee_id,privilege from acs_permissions
                                where object_id = p_folder_id
                 loop
                        perform acs_permission__grant_permission(
                                v_item_id,                      -- object_id
                                v_permission_row.grantee_id,    -- grantee_id
                                v_permission_row.privilege      -- privilege
                        );
                end loop;

                -- Insert row into static_pages:
                insert into static_pages
                        (static_page_id, filename, folder_id, show_comments_p)
                values (
                        v_item_id,
                        p_filename,
                        p_folder_id,
                        p_show_comments_p
                );

                return v_item_id;
end;' language 'plpgsql';

create	function static_page__new (

                integer, 	-- folder_id	in sp_folders.folder_id%TYPE,
                varchar, 	-- filename	in static_pages.filename%TYPE default null,
                varchar 	-- title	in cr_revisions.title%TYPE default null
        ) returns integer as '
	declare
                p_folder_id             alias for $1;
                p_filename              alias for $2;
                p_title                 alias for $3;
               
	        v_static_page_id	static_pages.static_page_id%TYPE;	       
                v_item_id	        static_pages.static_page_id%TYPE;

        begin
		return static_page__new (
			   NULL,	       -- static_page_id
			   p_folder_id,	       -- folder_id
			   p_filename,	       -- filename
			   p_title,	       -- title
			   NULL,	       -- content
			   ''t'',	       -- show_comments_p
			   now(),	       -- creation_date
			   NULL,	       -- creation_user
			   NULL,	       -- creation_ip
			   NULL		       -- conext_id
			   );
	       
end;' language 'plpgsql';


create	function static_page__delete (
                integer         -- static_page_id in static_pages.static_page_id%TYPE
        ) returns integer as '
        declare
                p_static_page_id        alias for $1;
                v_comment_row           RECORD;
		v_rec_affected		integer;
		v_static_page_id	integer;
        begin
                -- Delete all permissions on this page:

	delete from acs_permissions where object_id = p_static_page_id;

                -- Drop all comments on this page.  general-comments doesn''t have
                -- a comment.delete() function, so I just do this (see the
                -- general-comments drop script):

		for v_comment_row in 
                        select comment_id from general_comments
                        where object_id = p_static_page_id
                 loop
                        delete from images
                        where image_id in (
                                select latest_revision
                                from cr_items
                                where parent_id = v_comment_row.comment_id
                       );

                        PERFORM acs_message__delete(v_comment_row.comment_id);
                end loop;

                -- Delete the page.
                -- WE SHOULDN''T NEED TO DO THIS: CONTENT_ITEM.DELETE SHOULD TAKE CARE OF
                -- DELETING FROM STATIC PAGES.

	delete from static_pages where static_page_id = p_static_page_id;

	GET DIAGNOSTICS v_rec_affected = ROW_COUNT;
	RAISE NOTICE ''*** Number of rows deleted: %'',v_rec_affected;
	select into v_static_page_id static_page_id from static_pages where static_page_id = p_static_page_id;
	GET DIAGNOSTICS v_rec_affected = ROW_COUNT;
	RAISE NOTICE ''*** selected % rows still in static_pages'',v_rec_affected;


	PERFORM content_item__delete(p_static_page_id);
return 0;
end;' language 'plpgsql';

create	function static_page__get_root_folder (
                integer         -- package_id	in apm_packages.package_id%TYPE
        ) returns integer as '
        declare
                p_package_id            alias for $1;
                v_folder_exists_p	integer;
                v_folder_id	        sp_folders.folder_id%TYPE;
		v_rows			integer;
begin
                -- If there isn''t a root folder for this package, create one.
                -- Otherwise, just return its id.
                select count(*) into v_folder_exists_p where exists (
                        select 1 from sp_folders
                        where package_id = p_package_id
                        and parent_id is null
                );

                if v_folder_exists_p = 0 then

                        v_folder_id := static_page__new_folder (
                                null,
				''sp_root'',      -- name
                                ''sp_root'',       -- label
				null,
				null,
				null,
				null,
				null,
				null
                        );

                        update sp_folders
                                set package_id = p_package_id
                                where folder_id = v_folder_id;

                        PERFORM acs_permission__grant_permission (
                                v_folder_id,                            -- object_id
                                acs__magic_object_id(''the_public''),   -- grantee_id
                                ''general_comments_create''             -- privilege
                        );
                        -- The comments will inherit read permission from the pages,
                        -- so the public should be able to read the static pages.
                        PERFORM acs_permission__grant_permission (
                                v_folder_id,                            -- object_id
                                acs__magic_object_id(''the_public''),   -- grantee_id
                                ''read''                                  -- privilege
                        );
                else
                        select folder_id into v_folder_id from sp_folders
                        where package_id = p_package_id
                        and parent_id is null;
                end if;

                return v_folder_id;
end;' language 'plpgsql';

create	function static_page__new_folder (
                integer,        -- folder_id	in sp_folders.folder_id%TYPE
                                --        default null,
                varchar,        -- name	in cr_items.name%TYPE,
                varchar,        -- label	in cr_folders.label%TYPE,
                text,           -- description	in cr_folders.description%TYPE default null,
                integer,        -- parent_id	in cr_items.parent_id%TYPE default null,
                timestamp,      -- creation_date	in acs_objects.creation_date%TYPE
                                --        default sysdate,
                integer,        -- creation_user	in acs_objects.creation_user%TYPE
                                --        default null,
                varchar,        -- creation_ip	in acs_objects.creation_ip%TYPE
                                --        default null,
                integer         -- context_id	in acs_objects.context_id%TYPE
                                --        default null
        ) returns integer as '
        declare
                p_folder_id       alias for $1;
                p_name            alias for $2;
                p_label           alias for $3;
                p_description     alias for $4;
                p_parent_id       alias for $5;
                p_creation_date   alias for $6;
                p_creation_user   alias for $7;
                p_creation_ip     alias for $8;
                p_context_id      alias for $9;

                v_folder_id	        sp_folders.folder_id%TYPE;
                v_parent_id	        cr_items.parent_id%TYPE;
                v_package_id	        apm_packages.package_id%TYPE;
                v_creation_date         acs_objects.creation_date%TYPE;
                v_permission_row        RECORD;
        begin
                if p_creation_date is null then
                        v_creation_date := now();
                else
                        v_creation_date := p_creation_date;
                end if;

                if p_parent_id is null then
                        v_parent_id := 0;
                else
                        v_parent_id := p_parent_id;
                end if;

                v_folder_id := content_folder__new (
                        p_name,            -- name
                        p_label,           -- label
                        p_description,     -- description		
                        v_parent_id,       -- parent_id
                        p_context_id,      -- context_id
			p_folder_id,       -- folder_id
                        v_creation_date,   -- creation_date
                        p_creation_user,   -- creation_user
                        p_creation_ip,     -- creation_ip
			''f''		-- secuity_inherit_p	

                );

                if p_parent_id is not null then
                        -- Get the package_id from the parent:
                        select package_id into v_package_id from sp_folders
                                where folder_id = p_parent_id;

                        insert into sp_folders (folder_id, parent_id, package_id)
                                values (v_folder_id, p_parent_id, v_package_id);

--                        update acs_objects set security_inherit_p = ''f''
--                                where object_id = v_folder_id;

                        -- Copy permissions from the parent:
                        for v_permission_row in 
                                select * from acs_permissions
                                        where object_id = p_parent_id
                         loop
                                perform acs_permission__grant_permission(
                                        v_folder_id,                    -- object_id
                                        v_permission_row.grantee_id,    -- grantee_id
                                        v_permission_row.privilege      -- privilege
                                );
                        end loop;
                else
                        insert into sp_folders (folder_id, parent_id)
                                values (v_folder_id, p_parent_id);

                -- if it''s a root folder, allow it to contain static pages and
                -- other folders (subfolders will inherit these properties)
                PERFORM  content_folder__register_content_type (
                                v_folder_id,              -- folder_id
                                ''static_page'',           -- content_type
				''f''
                        );
                PERFORM  content_folder__register_content_type (
                                v_folder_id,            -- folder_id
                                ''content_revision'',      -- content_type
				''f''
                        );
                PERFORM  content_folder__register_content_type (
                                v_folder_id,            -- folder_id
                                ''content_folder'',      -- content_type
				''f''
                        );
                end if;

                return v_folder_id;
end;' language 'plpgsql';

create	function static_page__delete_folder (
                integer         -- folder_id	in sp_folders.folder_id%TYPE
        ) returns integer as '
        declare
                p_folder_id     alias for $1;
                v_folder_row    RECORD;
                v_page_row      RECORD;
        begin
                for v_folder_row in 
                        select folder_id from (
                                select folder_id, tree_level(tree_sortkey)  as path_depth, tree_sortkey from sp_folders
		where tree_sortkey like ( select tree_sortkey || ''%''
		from sp_folders
		where folder_id = p_folder_id)
                        ) folders order by path_depth desc
                 loop
                        for v_page_row in 
                                select static_page_id from static_pages
                                where folder_id = v_folder_row.folder_id
                         loop
                             PERFORM static_page__delete(v_page_row.static_page_id);
                        end loop;

                        delete from sp_folders where folder_id = v_folder_row.folder_id;
                        PERFORM content_folder__delete(v_folder_row.folder_id);
                end loop;
return 0;
end;' language 'plpgsql';

create	function static_page__delete_stale_items (
                integer,	-- session_id	in sp_extant_files.session_id%TYPE,
                integer		-- package_id	in apm_packages.package_id%TYPE
        ) returns integer as '
	declare
                p_session_id	        alias for $1;
                p_package_id	        alias for $2;
                v_root_folder_id	sp_folders.folder_id%TYPE;
		v_stale_file_row        RECORD;
		v_stale_folder_row      RECORD;
        begin
                v_root_folder_id := static_page__get_root_folder(p_package_id);

           -- First delete all files that are descendants of the root folder
           -- but aren''t in sp_extant_files
                
	for v_stale_file_row in 
	   select static_page_id from static_pages
		where folder_id in (
		   select folder_id from sp_folders
			where tree_sortkey like (
			   select tree_sortkey || ''%''
				from sp_folders
				where folder_id = v_root_folder_id )
				)
		and
		   static_page_id not in (
			select static_page_id from
			   sp_extant_files
				where session_id = p_session_id )
	loop
		PERFORM static_page__delete(v_stale_file_row.static_page_id);
	end loop;

-- Now delete all folders that aren''t in sp_extant_folders.  There are two
-- views created on the fly here: dead (all descendants of the root
-- folder not in sp_extant_folders) and path (each folder and its depth).
-- They are joined together to get the depth of all the folders that
-- need to be deleted.  The root folder is excluded because it won''t
-- show up in the filesystem search, so it will be missing from
-- sp_extant_folders.

		for v_stale_folder_row in 
                        select dead.folder_id  from
                        (select folder_id from sp_folders
                                where folder_id not in (
                                        select folder_id
                                        from sp_extant_folders
                                        where session_id = p_session_id
                                )
                        ) dead,
                        (select folder_id,tree_level(tree_sortkey) as depth, tree_sortkey from sp_folders
		where tree_sortkey like ( select tree_sortkey || ''%''
		from sp_folders
		where folder_id = v_root_folder_id)
                        ) path
                        where dead.folder_id = path.folder_id
                                and dead.folder_id <> v_root_folder_id
                        order by path.depth desc
                 loop
		delete from sp_folders
                        where folder_id = v_stale_folder_row.folder_id;
                        perform content_folder__delete(v_stale_folder_row.folder_id);
                end loop;

return 0;
end;' language 'plpgsql';

 
create	function static_page__grant_permission (
                integer,	-- item_id in acs_permissions.object_id%TYPE,
                integer,	-- grantee_id	in acs_permissions.grantee_id%TYPE,
                varchar,	-- privilege	in acs_permissions.privilege%TYPE,
                boolean		-- recursive_p	in char
        ) returns integer as '
	declare
                p_item_id	alias for $1;
                p_grantee_id	alias for $2;
                p_privilege	alias for $3;
                p_recursive_p	alias for $4;
		v_file_row	RECORD;
		v_folder_row	RECORD;
        begin
                if p_recursive_p = ''t'' then
                        -- For each folder that is a descendant of item_id, grant.
                        for v_folder_row in 
                                select folder_id from sp_folders
		where tree_sortkey like ( select tree_sortkey || ''%''
		from sp_folders
		where folder_id = p_item_id)
                         loop
                                perform acs_permission__grant_permission(
				v_folder_row.folder_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, grant.
                        for v_file_row in 
                                select static_page_id from static_pages
                                where folder_id in (
                                        select folder_id from sp_folders
		where tree_sortkey like ( select tree_sortkey || ''%''
		from sp_folders
		where folder_id = p_item_id)
                                )
                         loop
                                perform acs_permission__grant_permission(
				v_file_row.static_page_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                else
                        perform acs_permission__grant_permission(
				p_item_id,		-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                        );
                end if;
		return 0;
end;' language 'plpgsql';


create	function static_page__revoke_permission (
                integer,	-- item_id in acs_permissions.object_id%TYPE,
                integer,	-- grantee_id	in acs_permissions.grantee_id%TYPE,
                varchar,	-- privilege	in acs_permissions.privilege%TYPE,
                boolean		-- recursive_p	in char
        ) returns integer as '
	declare
                p_item_id	alias for $1;
                p_grantee_id	alias for $2;
                p_privilege	alias for $3;
                p_recursive_p	alias for $4;
		v_file_row	RECORD;
		v_folder_row	RECORD;
        begin
                if p_recursive_p = ''t'' then
                        -- For each folder that is a descendant of item_id, revoke.
                        for v_folder_row in 
                                select folder_id from sp_folders
		where tree_sortkey like ( select tree_sortkey || ''%''
		from sp_folders
		where folder_id = p_item_id)
                         loop
                                perform acs_permission__revoke_permission(
				v_folder_row.folder_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, revoke.
                        for v_file_row in 
                                select static_page_id from static_pages
                                where folder_id in (
                                        select folder_id from sp_folders
		where tree_sortkey like ( select tree_sortkey || ''%''
		from sp_folders
		where folder_id = p_item_id)
                                )
                         loop
                                perform acs_permission__revoke_permission(
				v_file_row.static_page_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                else
                        perform acs_permission__revoke_permission(
				p_item_id,		-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                        );
                end if;
		return 0;
end;' language 'plpgsql';

create	function static_page__five_n_spaces (
                integer		-- n	in integer
        ) returns varchar as '
	declare
		p_n	alias for $1;
                space_string	varchar(400);
        begin
                space_string := '''';
                for i in 1..p_n loop
                        space_string := space_string || ''&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'';
                end loop;
                return space_string;
end;' language 'plpgsql';

create	function static_page__set_show_comments_p (
                integer,	-- item_id	in acs_permissions.object_id%TYPE,
                boolean		-- show_comments_p	in static_pages.show_comments_p%TYPE
        ) returns integer as '
	declare
		p_item_id		alias for $1;
		p_show_comments_p 	alias for $2;
        begin
                update static_pages
                set show_comments_p = p_show_comments_p
                where static_page_id = p_item_id;
		return 0;
end;' language 'plpgsql';

create	function static_page__get_show_comments_p (
                integer		-- item_id in acs_permissions.object_id%TYPE
        ) returns boolean as '
	declare
		p_item_id 	alias for $1;	-- p_ stands for parameter
                v_show_comments_p	static_pages.show_comments_p%TYPE;
        begin
                select show_comments_p into v_show_comments_p from static_pages
                where static_page_id = p_item_id;

                return v_show_comments_p;
end;' language 'plpgsql';

-- end static_page;


