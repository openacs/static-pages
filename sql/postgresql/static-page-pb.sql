-- packages/static-pages/sql/postgresql/static-page-pb.sql
-- Package body ONLY.
-- @cvs-id $Id$ 


-- create or replace package body static_page as


create or replace function static_page__new (
                integer, 	-- static_page_id	in static_pages.static_page_id%TYPE
                         	--               default null,
                integer, 	-- folder_id	in sp_folders.folder_id%TYPE,
                varchar, 	-- filename	in static_pages.filename%TYPE default null,
                varchar, 	-- title	in cr_revisions.title%TYPE default null,
                text,           -- content	in cr_revisions.content%TYPE default null,
                boolean, 	-- show_comments_p	in static_pages.show_comments_p%TYPE default 't',
                timestamptz, 	-- creation_date	in acs_objects.creation_date%TYPE
                           	--             default sysdate,
                integer, 	-- creation_user	in acs_objects.creation_user%TYPE
                         	--               default null,
                varchar, 	-- creation_ip	in acs_objects.creation_ip%TYPE
                                --        default null,
                integer, 	-- context_id	in acs_objects.context_id%TYPE
                                --        default null
		integer		-- mtime
		,varchar        -- mime_type	in cr_revisions.mime_type%TYPE  default 'text/html'
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
		p_mtime			alias for $11;
		p_mime_type		alias for $12;

                v_item_id	        static_pages.static_page_id%TYPE;
                v_permission_row        RECORD;
		v_revision_id		integer;
		v_is_live		boolean default ''t'';
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
                        p_mime_type,			-- mime_type
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
                        (static_page_id, filename, folder_id, show_comments_p, mtime)
                values (
                        v_item_id,
                        p_filename,
                        p_folder_id,
                        p_show_comments_p,
			p_mtime
                );

                return v_item_id;
end;' language 'plpgsql';


create or replace function static_page__new (

                integer, 	-- folder_id	in sp_folders.folder_id%TYPE,
                varchar, 	-- filename	in static_pages.filename%TYPE default null,
                varchar, 	-- title	in cr_revisions.title%TYPE default null
		integer		-- mtime
		,varchar        -- mime_type	in cr_revisions.mime_type%TYPE  default 'text/html'
        ) returns integer as '
	declare
                p_folder_id             alias for $1;
                p_filename              alias for $2;
                p_title                 alias for $3;
		p_mtime			alias for $4;
		p_mime_type		alias for $5;
               
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
			   NULL,	       -- conext_id
			   p_mtime	       -- mtime
			   ,p_mime_type	       -- mime_type
			   );
	       
end;' language 'plpgsql';


create or replace function static_page__delete (
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


create or replace function static_page__get_root_folder (
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
			-- name NEEDS to be unique, label does not
                        v_folder_id := static_page__new_folder (
                                null,
				''sp_root_package_id_'' || p_package_id,      -- name
                                ''sp_root_package_id_'' || p_package_id,       -- label
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


create or replace function static_page__new_folder (
                integer,        -- folder_id	in sp_folders.folder_id%TYPE
                                --        default null,
                varchar,        -- name	in cr_items.name%TYPE,
                varchar,        -- label	in cr_folders.label%TYPE,
                text,           -- description	in cr_folders.description%TYPE default null,
                integer,        -- parent_id	in cr_items.parent_id%TYPE default null,
                timestamptz,    -- creation_date	in acs_objects.creation_date%TYPE
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


create or replace function static_page__delete_folder (
                integer         -- folder_id	in sp_folders.folder_id%TYPE
        ) returns integer as '
        declare
                p_folder_id     alias for $1;
                v_folder_row    RECORD;
                v_page_row      RECORD;
        begin
                for v_folder_row in
                  select s1.folder_id, tree_level(s1.tree_sortkey) as path_depth
                  from sp_folders s1, sp_folders s2
                  where s2.folder_id = p_folder_id
		    and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
                  order by path_depth desc
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


create or replace function static_page__delete_stale_items (
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
	   select sp.static_page_id 
           from static_pages sp, sp_folders s1, sp_folders s2
	   where sp.folder_id = s1.folder_id
             and s2.folder_id = v_root_folder_id
             and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
	     and not exists (select 1
                             from sp_extant_files sef
                             where sef.session_id = p_session_id
                             and sp.static_page_id = sef.static_page_id)
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
                        (select s1.folder_id,tree_level(s1.tree_sortkey) as depth
                         from sp_folders s1, sp_folders s2
                         where s2.folder_id = v_root_folder_id
                           and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
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

 
create or replace function static_page__grant_permission (
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
                          select s1.folder_id from sp_folders s1, sp_folders s2
                          where s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
                         loop
                                perform acs_permission__grant_permission(
				v_folder_row.folder_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, grant.
                        for v_file_row in 
                          select sp.static_page_id
                          from static_pages sp, sp_folders s1, sp_folders s2
                          where sp.folder_id = s1.folder_id
                            and s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
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


create or replace function static_page__revoke_permission (
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
                          select s1.folder_id from sp_folders s1, sp_folders s2
                          where s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
                         loop
                                perform acs_permission__revoke_permission(
				v_folder_row.folder_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, revoke.
                        for v_file_row in 
                          select sp.static_page_id
                          from static_pages sp, sp_folders s1, sp_folders s2
                          where sp.folder_id = s1.folder_id
                            and s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
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


create or replace function static_page__five_n_spaces (
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


create or replace function static_page__set_show_comments_p (
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


create or replace function static_page__get_show_comments_p (
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

create or replace function static_page__new (
                integer, 	-- static_page_id	in static_pages.static_page_id%TYPE
                         	--               default null,
                integer, 	-- folder_id	in sp_folders.folder_id%TYPE,
                varchar, 	-- filename	in static_pages.filename%TYPE default null,
                varchar, 	-- title	in cr_revisions.title%TYPE default null,
                text,           -- content	in cr_revisions.content%TYPE default null,
                boolean, 	-- show_comments_p	in static_pages.show_comments_p%TYPE default 't',
                timestamptz, 	-- creation_date	in acs_objects.creation_date%TYPE
                           	--             default sysdate,
                integer, 	-- creation_user	in acs_objects.creation_user%TYPE
                         	--               default null,
                varchar, 	-- creation_ip	in acs_objects.creation_ip%TYPE
                                --        default null,
                integer, 	-- context_id	in acs_objects.context_id%TYPE
                                --        default null
		integer		-- mtime
		,varchar        -- mime_type	in cr_revisions.mime_type%TYPE  default 'text/html'
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
		p_mtime			alias for $11;
		p_mime_type		alias for $12;

                v_item_id	        static_pages.static_page_id%TYPE;
                v_permission_row        RECORD;
		v_revision_id		integer;
		v_is_live		boolean default ''t'';
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
                        p_mime_type,			-- mime_type
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
                        (static_page_id, filename, folder_id, show_comments_p, mtime)
                values (
                        v_item_id,
                        p_filename,
                        p_folder_id,
                        p_show_comments_p,
			p_mtime
                );

                return v_item_id;
end;' language 'plpgsql';


create or replace function static_page__new (

                integer, 	-- folder_id	in sp_folders.folder_id%TYPE,
                varchar, 	-- filename	in static_pages.filename%TYPE default null,
                varchar, 	-- title	in cr_revisions.title%TYPE default null
		integer		-- mtime
		,varchar        -- mime_type	in cr_revisions.mime_type%TYPE  default 'text/html'
        ) returns integer as '
	declare
                p_folder_id             alias for $1;
                p_filename              alias for $2;
                p_title                 alias for $3;
		p_mtime			alias for $4;
		p_mime_type		alias for $5;
               
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
			   NULL,	       -- conext_id
			   p_mtime	       -- mtime
			   ,p_mime_type	       -- mime_type
			   );
	       
end;' language 'plpgsql';


create or replace function static_page__delete (
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


create or replace function static_page__get_root_folder (
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
			-- name NEEDS to be unique, label does not
                        v_folder_id := static_page__new_folder (
                                null,
				''sp_root_package_id_'' || p_package_id,      -- name
                                ''sp_root_package_id_'' || p_package_id,       -- label
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


create or replace function static_page__new_folder (
                integer,        -- folder_id	in sp_folders.folder_id%TYPE
                                --        default null,
                varchar,        -- name	in cr_items.name%TYPE,
                varchar,        -- label	in cr_folders.label%TYPE,
                text,           -- description	in cr_folders.description%TYPE default null,
                integer,        -- parent_id	in cr_items.parent_id%TYPE default null,
                timestamptz,    -- creation_date	in acs_objects.creation_date%TYPE
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


create or replace function static_page__delete_folder (
                integer         -- folder_id	in sp_folders.folder_id%TYPE
        ) returns integer as '
        declare
                p_folder_id     alias for $1;
                v_folder_row    RECORD;
                v_page_row      RECORD;
        begin
                for v_folder_row in
                  select s1.folder_id, tree_level(s1.tree_sortkey) as path_depth
                  from sp_folders s1, sp_folders s2
                  where s2.folder_id = p_folder_id
		    and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
                  order by path_depth desc
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


create or replace function static_page__delete_stale_items (
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
	   select sp.static_page_id 
           from static_pages sp, sp_folders s1, sp_folders s2
	   where sp.folder_id = s1.folder_id
             and s2.folder_id = v_root_folder_id
             and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
	     and not exists (select 1
                             from sp_extant_files sef
                             where sef.session_id = p_session_id
                             and sp.static_page_id = sef.static_page_id)
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
                        (select s1.folder_id,tree_level(s1.tree_sortkey) as depth
                         from sp_folders s1, sp_folders s2
                         where s2.folder_id = v_root_folder_id
                           and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
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

 
create or replace function static_page__grant_permission (
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
                          select s1.folder_id from sp_folders s1, sp_folders s2
                          where s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
                         loop
                                perform acs_permission__grant_permission(
				v_folder_row.folder_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, grant.
                        for v_file_row in 
                          select sp.static_page_id
                          from static_pages sp, sp_folders s1, sp_folders s2
                          where sp.folder_id = s1.folder_id
                            and s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
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


create or replace function static_page__revoke_permission (
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
                          select s1.folder_id from sp_folders s1, sp_folders s2
                          where s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
                         loop
                                perform acs_permission__revoke_permission(
				v_folder_row.folder_id,	-- object_id 
				p_grantee_id,		-- grantee_id
				p_privilege		-- privilege 
                                );
                        end loop;
                        -- For each file that is a descendant of item_id, revoke.
                        for v_file_row in 
                          select sp.static_page_id
                          from static_pages sp, sp_folders s1, sp_folders s2
                          where sp.folder_id = s1.folder_id
                            and s2.folder_id = p_item_id
                            and s1.tree_sortkey between s2.tree_sortkey and tree_right(s2.tree_sortkey)
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


create or replace function static_page__five_n_spaces (
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


create or replace function static_page__set_show_comments_p (
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


create or replace function static_page__get_show_comments_p (
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
