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
show errors
