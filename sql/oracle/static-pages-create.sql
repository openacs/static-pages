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


-- TODO: Why exactly do we need the sp_folders table to completely
-- mirror the hierarchy in the Content Repository, rather than just
-- using a small table to point to the root folders, the way File
-- Storage does?  --atp@piskorski.com, 2001/08/26 21:30 EDT

-- TODO: A root folder has a null sp_folders.parent_id, but we can't
-- index nulls so may want to add a separate sp_root_folders table or
-- something.  --atp@piskorski.com, 2001/08/26 22:47 EDT


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
  --
  No, not anymore.  As of c. 2001/10/30 changes by daveb, it is a
  RELATIVE path, relative to the page root (server/www/).  As of now,
  it is relative to the server root (server/).  --atp@piskorski.com,
  2002/12/12 16:56 EST
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
show errros


@static-page-ph.sql
@static-page-pb.sql
