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
                        references apm_packages
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
create sequence sp_session_id_seq;


-- this also creates the acs_object type
        select content_type__create_type (
		'static_page',		-- content_type 
		null,			-- supertype    
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
                content	in cr_revisions.content%TYPE default null,
                boolean, 	-- show_comments_p	in static_pages.show_comments_p%TYPE default 't',
                timestamp, 	-- creation_date	in acs_objects.creation_date%TYPE
                           	--             default sysdate,
                integer, 	-- creation_user	in acs_objects.creation_user%TYPE
                         	--               default null,
                varchar, 	-- creation_ip	in acs_objects.creation_ip%TYPE
                                        default null,
                integer 	-- context_id	in acs_objects.context_id%TYPE
                                --        default null
        ) return static_pages.static_page_id%TYPE is
                v_item_id	static_pages.static_page_id%TYPE;
	declare
                static_page_id	in static_pages.static_page_id%TYPE
                                        default null,
                folder_id	in sp_folders.folder_id%TYPE,
                filename	in static_pages.filename%TYPE default null,
                title	in cr_revisions.title%TYPE default null,
                content	in cr_revisions.content%TYPE default null,
                show_comments_p	in static_pages.show_comments_p%TYPE default 't',
                creation_date	in acs_objects.creation_date%TYPE
                                        default sysdate,
                creation_user	in acs_objects.creation_user%TYPE
                                        default null,
                creation_ip	in acs_objects.creation_ip%TYPE
                                        default null,
                context_id	in acs_objects.context_id%TYPE
                                        default null
        begin
                -- Create content item; this also makes the content revision.
                -- One might be tempted to set the content_type to static_page,
                -- But this would confuse site-wide-search, which expects to
                -- see a content_type of content_revision.
                v_item_id := content_item.new(
                        item_id	=> static_page.new.static_page_id,
                        parent_id	=> static_page.new.folder_id,
                        name	=> static_page.new.filename,
                        title	=> static_page.new.title,
                        mime_type	=> 'text/html',
                        creation_date	=> static_page.new.creation_date,
                        creation_user	=> static_page.new.creation_user,
                        creation_ip	=> static_page.new.creation_ip,
                        context_id	=> static_page.new.context_id,
                        is_live	=> 't',
                        data	=> static_page.new.content
                );

                -- We want to be able to have non-commentable folders below
                -- commentable folders.  We can't do this if we leave security
                -- inheritance enabled.
                --
                update acs_objects set security_inherit_p = 'f'
                        where object_id = v_item_id;

                -- Copy permissions from the parent:
                for permission_row in (
                        select grantee_id,privilege from acs_permissions
                                where object_id = folder_id
                ) loop
                        acs_permission.grant_permission(
                                object_id => v_item_id,
                                grantee_id => permission_row.grantee_id,
                                privilege => permission_row.privilege
                        );
                end loop;

                -- Insert row into static_pages:
                insert into static_pages
                        (static_page_id, filename, folder_id, show_comments_p)
                values (
                        v_item_id,
                        static_page.new.filename,
                        static_page.new.folder_id,
                        static_page.new.show_comments_p
                );

                return v_item_id;
end;' language 'plpgsql';

create	function static_page__delete (
                static_page_id	in static_pages.static_page_id%TYPE
        ) is
        begin
                -- Delete all permissions on this page:
                delete from acs_permissions where object_id = static_page_id;

                -- Drop all comments on this page.  general-comments doesn't have
                -- a comment.delete() function, so I just do this (see the
                -- general-comments drop script):
                for comment_row in (
                        select comment_id from general_comments
                        where object_id = static_page_id
                ) loop
                        delete from images
                        where image_id in (
                                select latest_revision
                                from cr_items
                                where parent_id = comment_row.comment_id
                        );

                        acs_message.delete(comment_row.comment_id);
                end loop;

                -- Delete the page.
                -- WE SHOULDN'T NEED TO DO THIS: CONTENT_ITEM.DELETE SHOULD TAKE CARE OF
                -- DELETING FROM STATIC PAGES.
                delete from static_pages where static_page_id = static_page.delete.static_page_id;
                content_item.delete(static_page_id);
end;' language 'plpgsql';

create	function static_page__get_root_folder (
                package_id	in apm_packages.package_id%TYPE
        ) return sp_folders.folder_id%TYPE is
                folder_exists_p	integer;
                folder_id	sp_folders.folder_id%TYPE;
        begin
                -- If there isn't a root folder for this package, create one.
                -- Otherwise, just return its id.
                select count(*) into folder_exists_p from dual where exists (
                        select 1 from sp_folders
                        where package_id = static_page.get_root_folder.package_id
                        and parent_id is null
                );

                if folder_exists_p = 0 then
                        folder_id := static_page.new_folder (
                                name => 'sp_root',
                                label => 'sp_root'
                        );

                        update sp_folders
                                set package_id = static_page.get_root_folder.package_id
                                where folder_id = static_page.get_root_folder.folder_id;

                        acs_permission.grant_permission (
                                object_id => folder_id,
                                grantee_id => acs.magic_object_id('the_public'),
                                privilege => 'general_comments_create'
                        );
                        -- The comments will inherit read permission from the pages,
                        -- so the public should be able to read the static pages.
                        acs_permission.grant_permission (
                                object_id => folder_id,
                                grantee_id => acs.magic_object_id('the_public'),
                                privilege => 'read'
                        );
                else
                        select folder_id into folder_id from sp_folders
                        where package_id = static_page.get_root_folder.package_id
                        and parent_id is null;
                end if;

                return folder_id;
end;' language 'plpgsql';


create	function static_page__new_folder (
                folder_id	in sp_folders.folder_id%TYPE
                                        default null,
                name	in cr_items.name%TYPE,
                label	in cr_folders.label%TYPE,
                description	in cr_folders.description%TYPE default null,
                parent_id	in cr_items.parent_id%TYPE default null,
                creation_date	in acs_objects.creation_date%TYPE
                                        default sysdate,
                creation_user	in acs_objects.creation_user%TYPE
                                        default null,
                creation_ip	in acs_objects.creation_ip%TYPE
                                        default null,
                context_id	in acs_objects.context_id%TYPE
                                        default null
        ) return sp_folders.folder_id%TYPE is
                v_folder_id	sp_folders.folder_id%TYPE;
                v_parent_id	cr_items.parent_id%TYPE;
                v_package_id	apm_packages.package_id%TYPE;
        begin
                if parent_id is null then
                        v_parent_id := 0;
                else
                        v_parent_id := parent_id;
                end if;

                v_folder_id := content_folder.new (
                        name	=> static_page.new_folder.name,
                        label	=> static_page.new_folder.label,
                        folder_id	=> static_page.new_folder.folder_id,
                        parent_id	=> v_parent_id,
                        description	=> static_page.new_folder.description,
                        creation_date	=> static_page.new_folder.creation_date,
                        creation_user	=> static_page.new_folder.creation_user,
                        creation_ip	=> static_page.new_folder.creation_ip,
                        context_id	=> static_page.new_folder.context_id
                );

                if parent_id is not null then
                        -- Get the package_id from the parent:
                        select package_id into v_package_id from sp_folders
                                where folder_id = static_page.new_folder.parent_id;

                        insert into sp_folders (folder_id, parent_id, package_id)
                                values (v_folder_id, parent_id, v_package_id);

                        update acs_objects set security_inherit_p = 'f'
                                where object_id = v_folder_id;

                        -- Copy permissions from the parent:
                        for permission_row in (
                                select grantee_id,privilege from acs_permissions
                                        where object_id = parent_id
                        ) loop
                                acs_permission.grant_permission(
                                        object_id => v_folder_id,
                                        grantee_id => permission_row.grantee_id,
                                        privilege => permission_row.privilege
                                );
                        end loop;
                else
                        insert into sp_folders (folder_id, parent_id)
                                values (v_folder_id, parent_id);

                -- if it's a root folder, allow it to contain static pages and
                -- other folders (subfolders will inherit these properties)
                        content_folder.register_content_type (
                                folder_id => v_folder_id,
                                content_type => 'static_page'
                        );
                        content_folder.register_content_type (
                                folder_id => v_folder_id,
                                content_type => 'content_revision'
                        );
                        content_folder.register_content_type (
                                folder_id => v_folder_id,
                                content_type => 'content_folder'
                        );
                end if;

                return v_folder_id;
end;' language 'plpgsql';

create	function static_page__delete_folder (
                folder_id	in sp_folders.folder_id%TYPE
        ) is
        begin
                for folder_row in (
                        select folder_id from (
                                select folder_id,level as path_depth from sp_folders
                                start with folder_id = static_page.delete_folder.folder_id
                                connect by parent_id = prior folder_id
                        ) order by path_depth desc
                ) loop
                        for page_row in (
                                select static_page_id from static_pages
                                where folder_id = folder_row.folder_id
                        ) loop
                                static_page.delete(page_row.static_page_id);
                        end loop;

                        delete from sp_folders where folder_id = folder_row.folder_id;
                        content_folder.delete(folder_row.folder_id);
                end loop;
end;' language 'plpgsql';

create	function static_page__delete_stale_items (
                integer,	-- session_id	in sp_extant_files.session_id%TYPE,
                integer		-- package_id	in apm_packages.package_id%TYPE
        ) returns integer as '
	declare
                p_session_id	alias for $1;
                p_package_id	alias for $2;
                root_folder_id	sp_folders.folder_id%TYPE;
		v_stale_file_row static_pages.static_page_id%TYPE;	
		v_stale_folder_row sp_folders.folder_id%TYPE;
        begin
                root_folder_id := static_page__get_root_folder(p_package_id);

                -- First delete all files that are descendants of the root folder
                -- but aren''t in sp_extant_files:
                --
                for v_stale_file_row in (
                        select static_page_id from static_pages
                        where folder_id in (
                                select folder_id from sp_folders
                                start with folder_id = root_folder_id
                                connect by parent_id = prior folder_id
                        ) and static_page_id not in (
                                select static_page_id
                                from sp_extant_files
                                where session_id = p_session_id
                        )
                ) loop
                        static_page__delete(v_stale_file_row);
                end loop;

                -- Now delete all folders that aren''t in sp_extant_folders.  There are two
                -- views created on the fly here: dead (all descendants of the root
                -- folder not in sp_extant_folders) and path (each folder and its depth).
                -- They are joined together to get the depth of all the folders that
                -- need to be deleted.  The root folder is excluded because it won''t
                -- show up in the filesystem search, so it will be missing from
                -- sp_extant_folders.
                --
                for stale_folder_row in (
                        select dead.folder_id from
                        (select folder_id from sp_folders
                                where (folder_id) not in (
                                        select folder_id
                                        from sp_extant_folders
                                        where session_id = p_session_id
                                )
                        ) dead,
                        (select folder_id,level as depth from sp_folders
                                start with folder_id = root_folder_id
                                connect by parent_id = prior folder_id
                        ) path
                        where dead.folder_id = path.folder_id
                                and dead.folder_id <> root_folder_id
                        order by path.depth desc
                ) loop
                        delete from sp_folders
                        where folder_id = v_stale_folder_row;

                        content_folder__delete(v_stale_folder_row);
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
		v_file_row	static_pages.static_page_id%TYPE;
		v_folder_row	sp_folders.folder_id%TYPE;
        begin
                if recursive_p = 't' then
                        -- For each folder that is a descendant of item_id, grant.
                        for v_folder_row in (
                                select folder_id from sp_folders
                                start with folder_id = p_item_id
                                connect by parent_id = prior folder_id
                        ) loop
                                acs_permission__grant_permission(
				v_folder_row,		-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, grant.
                        for file_row in (
                                select static_page_id from static_pages
                                where folder_id in (
                                        select folder_id from sp_folders
                                        start with folder_id = p_item_id
                                        connect by parent_id = prior folder_id
                                )
                        ) loop
                                acs_permission__grant_permission(
				v_file_row,		-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                else
                        acs_permission__grant_permission(
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
		v_file_row	static_pages.static_page_id%TYPE;
		v_folder_row	sp_folders.folder_id%TYPE;
        begin
                if p_recursive_p = 't' then
                        -- For each folder that is a descendant of item_id, revoke.
                        for v_folder_row in (
                                select folder_id from sp_folders
                                start with folder_id = p_item_id
                                connect by parent_id = prior folder_id
                        ) loop
                                acs_permission__revoke_permission(
				v_folder_row,		-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, revoke.
                        for v_file_row in (
                                select static_page_id from static_pages
                                where folder_id in (
                                        select folder_id from sp_folders
                                        start with folder_id = p_item_id
                                        connect by parent_id = prior folder_id
                                )
                        ) loop
                                acs_permission__revoke_permission(
				v_file_row,		-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                else
                        acs_permission__revoke_permission(
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
        ) returns static_pages.show_comments_p%TYPE as '
	declare
		p_item_id 	alias for $1;	-- p_ stands for parameter
                v_show_comments_p	static_pages.show_comments_p%TYPE;
        begin
                select show_comments_p into v_show_comments_p from static_pages
                where static_page_id = p_item_id;

                return v_show_comments_p;
end;' language 'plpgsql';

-- end static_page;


