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

set def off

create table sp_folders (
	folder_id	constraint sp_folders_folder_id_pk
			primary key
			constraint sp_folders_folder_id_fk
			references cr_folders,
	parent_id	constraint sp_folders_parent_id_fk
			references sp_folders(folder_id),
	package_id	constraint sp_folders_package_id_fk
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
	static_page_id	constraint static_pgs_static_pg_id_fk
			references cr_items
			constraint static_pgs_static_pg_pk
			primary key,
	filename	varchar2(500),
	folder_id	constraint static_pgs_folder_id_fk
			references sp_folders,
	show_comments_p	char(1)
			default 't'
			constraint static_pgs_show_cmnts_nn
			not null
			constraint static_pgs_show_cmnts_chk
			check (show_comments_p in ('t','f'))
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
	static_page_id	not null
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
	folder_id	not null
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


declare
	attr_id	acs_attributes.attribute_id%TYPE;
begin
-- this also creates the acs_object type
	content_type.create_type (
	  content_type   => 'static_page',
	  pretty_name    => 'Static Page',
	  pretty_plural  => 'Static Pages',
	  table_name     => 'static_pages',
	  id_column      => 'static_page_id'
	);

	attr_id := content_type.create_attribute (
	  content_type   => 'static_page',
	  attribute_name => 'filename',
	  datatype       => 'text',
	  pretty_name    => 'Filename',
	  pretty_plural  => 'Filenames',
	  column_spec    => 'varchar2(500)'
	);
end;
/


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
	) return static_pages.static_page_id%TYPE;

	procedure delete (
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
	end;

	procedure delete (
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
				static_page.delete(page_row.static_page_id);
			end loop;

			delete from sp_folders where folder_id = folder_row.folder_id;
			content_folder.delete(folder_row.folder_id);
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
			static_page.delete(stale_file_row.static_page_id);
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

			content_folder.delete(stale_folder_row.folder_id);
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
