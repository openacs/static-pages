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
				null,
                                p_package_id
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


-- The one that does not take package_id should just go away.
drop function static_page__new_folder (integer, character varying, character varying, text, integer, timestamp with time zone, integer, character varying, integer);

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
                integer,        -- context_id	in acs_objects.context_id%TYPE
                                --        default null
                integer         -- package_id
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
                p_package_id      alias for $10;

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


                if p_parent_id is not null then
                        if p_package_id is null then
                                -- Get the package_id from the parent:
                                select package_id into v_package_id from sp_folders
                                        where folder_id = p_parent_id;
                        else
                                v_package_id := p_package_id;
                        end if;
                else
                        v_package_id := p_package_id;
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
			''f'',             -- secuity_inherit_p	
                        v_package_id
                );


                if p_parent_id is not null then
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
                        insert into sp_folders (folder_id, parent_id, package_id)
                                values (v_folder_id, p_parent_id, p_package_id);

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

