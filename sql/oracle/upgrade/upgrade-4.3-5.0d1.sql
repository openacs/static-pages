-- packages/static-pages/sql/oracle/static-page-ph.sql
-- Package header ONLY.
-- @cvs-id $Id$ 
-- @author Brandoch Calef (bcalef@arsdigita.com)


create or replace package static_page as
	function new (
	-- /**
	--  *  Creates a new content_item and content_revision for a
	--  *  static page.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-02
	--  **/
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
		,mime_type      in cr_revisions.mime_type%TYPE  default 'text/html'
	) return static_pages.static_page_id%TYPE;

	procedure del (
	-- /**
	--  *  Delete a static page, including the associated content_item.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-02
	--  **/
		static_page_id	in static_pages.static_page_id%TYPE
	);

	function get_root_folder (
	-- /**
	--  *  Returns the id of the root folder belonging to this package.
	--  *  If none exists, one is created.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-22
	--  **/
		package_id	in apm_packages.package_id%TYPE
	) return sp_folders.folder_id%TYPE;

	function new_folder (
	-- /**
	--  *  Create a folder in the content_repository to hold files in
	--  *  a particular directory.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-02
	--  **/
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
	) return sp_folders.folder_id%TYPE;

	procedure delete_folder (
	-- /**
	--  *  Delete a folder and all the folders and files it contains.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-02
	--  **/
		folder_id	in sp_folders.folder_id%TYPE
	);

	procedure delete_stale_items (
	-- /**
	--  *  Delete items that are in the content repository but not in
	--  *  extant_files/extant_folders with the given session_id.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-02
	--  **/
		session_id	in sp_extant_files.session_id%TYPE,
		package_id	in apm_packages.package_id%TYPE
	);

	procedure grant_permission (
	-- /**
	--  *  Grant a privilege on a file or folder, perhaps recursively.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-21
	--  **/
		item_id		in acs_permissions.object_id%TYPE,
		grantee_id	in acs_permissions.grantee_id%TYPE,
		privilege	in acs_permissions.privilege%TYPE,
		recursive_p	in char
	);

	procedure revoke_permission (
	-- /**
	--  *  Revoke a privilege on a file or folder, perhaps recursively.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-21
	--  **/
		item_id		in acs_permissions.object_id%TYPE,
		grantee_id	in acs_permissions.grantee_id%TYPE,
		privilege	in acs_permissions.privilege%TYPE,
		recursive_p	in char
	);

	function five_n_spaces (
	-- /**
	--  *  Return 5n nonbreaking spaces.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-27
	--  **/
		n	in integer
	) return varchar2;

	procedure set_show_comments_p (
	-- /**
	--  *  Establish whether the contents of a comment are displayed
	--  *  on a particular page.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-23
	--  **/
		item_id		in acs_permissions.object_id%TYPE,
		show_comments_p	in static_pages.show_comments_p%TYPE
	);

	function get_show_comments_p (
	-- /**
	--  *  Retrieve the comment display policy.
	--  *
	--  *  @author Brandoch Calef
	--  *  @creation-date 2001-02-23
	--  **/
		item_id		in acs_permissions.object_id%TYPE
	) return static_pages.show_comments_p%TYPE;
	
end static_page;
/
show errors
-- packages/static-pages/sql/oracle/static-page-pb.sql
-- Package body ONLY.
-- @cvs-id $Id$ 
-- @author Brandoch Calef (bcalef@arsdigita.com)

set def off

create or replace package body static_page as
	function new (
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
		,mime_type      in cr_revisions.mime_type%TYPE  default 'text/html'
	) return static_pages.static_page_id%TYPE is
		v_item_id	static_pages.static_page_id%TYPE;
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
			mime_type       => static_page.new.mime_type,
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
	end;

	procedure del (
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

			acs_message.del(comment_row.comment_id);
		end loop;

		-- Delete the page.
		-- WE SHOULDN'T NEED TO DO THIS: CONTENT_ITEM.DELETE SHOULD TAKE CARE OF
		-- DELETING FROM STATIC PAGES.
		delete from static_pages where static_page_id = static_page.del.static_page_id;
		content_item.del(static_page_id);
	end;

	function get_root_folder (
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
			  -- name NEEDS to be unique, label does not
			  name  => 'sp_root_package_id_' || package_id,
			  label => 'sp_root_package_id_' || package_id
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
	end get_root_folder;


	function new_folder (
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
	end;

	procedure delete_folder (
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
				static_page.del(page_row.static_page_id);
			end loop;

			delete from sp_folders where folder_id = folder_row.folder_id;
			content_folder.del(folder_row.folder_id);
		end loop;
	end;

	procedure delete_stale_items (
		session_id	in sp_extant_files.session_id%TYPE,
		package_id	in apm_packages.package_id%TYPE
	) is
		root_folder_id	sp_folders.folder_id%TYPE;
	begin
		root_folder_id := static_page.get_root_folder(package_id);

		-- First delete all files that are descendants of the root folder
		-- but aren't in sp_extant_files:
		--
		for stale_file_row in (
			select static_page_id from static_pages
			where folder_id in (
				select folder_id from sp_folders
				start with folder_id = root_folder_id
				connect by parent_id = prior folder_id
			) and static_page_id not in (
				select static_page_id
				from sp_extant_files
				where session_id = static_page.delete_stale_items.session_id
			)
		) loop
			static_page.del(stale_file_row.static_page_id);
		end loop;

		-- Now delete all folders that aren't in sp_extant_folders.  There are two
		-- views created on the fly here: dead (all descendants of the root
		-- folder not in sp_extant_folders) and path (each folder and its depth).
		-- They are joined together to get the depth of all the folders that
		-- need to be deleted.  The root folder is excluded because it won't
		-- show up in the filesystem search, so it will be missing from
		-- sp_extant_folders.
		--
		for stale_folder_row in (
			select dead.folder_id from
			(select folder_id from sp_folders
				where (folder_id) not in (
					select folder_id
					from sp_extant_folders
					where session_id = static_page.delete_stale_items.session_id
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
			where folder_id = stale_folder_row.folder_id;

			content_folder.del(stale_folder_row.folder_id);
		end loop;
	end delete_stale_items;

	procedure grant_permission (
		item_id		in acs_permissions.object_id%TYPE,
		grantee_id	in acs_permissions.grantee_id%TYPE,
		privilege	in acs_permissions.privilege%TYPE,
		recursive_p	in char
	) is
	begin
		if recursive_p = 't' then
			-- For each folder that is a descendant of item_id, grant.
			for folder_row in (
				select folder_id from sp_folders
				start with folder_id = item_id
				connect by parent_id = prior folder_id
			) loop
				acs_permission.grant_permission(
					object_id => folder_row.folder_id,
					grantee_id => static_page.grant_permission.grantee_id,
					privilege => static_page.grant_permission.privilege
				);
			end loop;
			-- For each file that is a descendant of item_id, grant.
			for file_row in (
				select static_page_id from static_pages	
				where folder_id in (
					select folder_id from sp_folders 
					start with folder_id = item_id
					connect by parent_id = prior folder_id
				)
			) loop
				acs_permission.grant_permission(
					object_id => file_row.static_page_id,
					grantee_id => static_page.grant_permission.grantee_id,
					privilege => static_page.grant_permission.privilege
				);
			end loop;
		else
			acs_permission.grant_permission(
				object_id => item_id,
				grantee_id => static_page.grant_permission.grantee_id,
				privilege => static_page.grant_permission.privilege
			);
		end if;
	end grant_permission;

	procedure revoke_permission (
		item_id		in acs_permissions.object_id%TYPE,
		grantee_id	in acs_permissions.grantee_id%TYPE,
		privilege	in acs_permissions.privilege%TYPE,
		recursive_p	in char
	) is
	begin
		if recursive_p = 't' then
			-- For each folder that is a descendant of item_id, revoke.
			for folder_row in (
				select folder_id from sp_folders
				start with folder_id = item_id
				connect by parent_id = prior folder_id
			) loop
				acs_permission.revoke_permission(
					object_id => folder_row.folder_id,
					grantee_id => static_page.revoke_permission.grantee_id,
					privilege => static_page.revoke_permission.privilege
				);
			end loop;
			-- For each file that is a descendant of item_id, revoke.
			for file_row in (
				select static_page_id from static_pages	
				where folder_id in (
					select folder_id from sp_folders 
					start with folder_id = item_id
					connect by parent_id = prior folder_id
				)
			) loop
				acs_permission.revoke_permission(
					object_id => file_row.static_page_id,
					grantee_id => static_page.revoke_permission.grantee_id,
					privilege => static_page.revoke_permission.privilege
				);
			end loop;
		else
			acs_permission.revoke_permission(
				object_id => item_id,
				grantee_id => static_page.revoke_permission.grantee_id,
				privilege => static_page.revoke_permission.privilege
			);
		end if;
	end revoke_permission;

	function five_n_spaces (
		n	in integer
	) return varchar2 is
		space_string	varchar2(400);
	begin
		space_string := '';
		for i in 1..n loop
			space_string := space_string || '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
		end loop;
		return space_string;
	end five_n_spaces;

	procedure set_show_comments_p (
		item_id		in acs_permissions.object_id%TYPE,
		show_comments_p	in static_pages.show_comments_p%TYPE
	) is
        begin
		update static_pages
		set show_comments_p = static_page.set_show_comments_p.show_comments_p
		where static_page_id = static_page.set_show_comments_p.item_id;
	end;

	function get_show_comments_p (
		item_id		in acs_permissions.object_id%TYPE
	) return static_pages.show_comments_p%TYPE is
		v_show_comments_p	static_pages.show_comments_p%TYPE;
	begin
		select show_comments_p into v_show_comments_p from static_pages
		where static_page_id = static_page.get_show_comments_p.item_id;

		return v_show_comments_p;
	end;

end static_page;
/
show errors
