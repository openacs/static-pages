# packages/static-pages/tcl/static-pages-procs.tcl
ad_library {
    Utilities for static pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-01-22
    @cvs-id $Id$
}


ad_proc -public sp_sync_cr_with_filesystem { 
    {
	-file_add_proc ""
	-file_change_proc ""
	-file_unchanged_proc ""
	-folder_add_proc ""
	-folder_unchanged_proc ""
    }
    fs_root
    root_folder_id
    {
	static_page_regexp {\.html?$}
    }
} {
    Synchronize the content repository with the file system.
    This creates entries in sp_folders and static_pages, so the static_page
    functions must be used to delete entries.

    @param file_add_proc The name of a Tcl proc to be called for each file
                         added.  The full file path and the page_id will be
                         passed to it.

    @param file_change_proc The name of a Tcl proc to be called for each file
                            changed in the database.

    @param file_unchanged_proc The name of a Tcl proc to be called for each file
                            unchanged in the database.

    @param folder_add_proc The name of a Tcl proc to be called for each folder
                           added.  The full file path and the folder_id will be
                           passed to it.

    @param folder_unchanged_proc The name of a Tcl proc to be called for each folder
                                 unchanged in the database.

    @param fs_root The starting path in the filesystem. This is relative to the openacs install directory,  Files below this point will 
                   be scanned.

    @param root_folder_id The id of the root folder in the static-pages system (and in 
                          the content repository) obtained from 
                          <code>static_page.get_root_folder</code>.

    @param static_page_regexp A regexp to identify static pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-07
} {
    set sync_session_id [db_nextval sp_session_id_seq]

    set fs_trimmed [string trimright $fs_root "/"]
    set fs_trimmed_length [string length $fs_trimmed]

    foreach file [ad_find_all_files $fs_root] {
	if { [regexp -nocase $static_page_regexp $file match] } {
	    # Chop the starting path off of the full pathname and split it up:
	    set path [split [string range $file $fs_trimmed_length end] "/"]
	    # Throw away the first entry (empty) and the last entry (which is the filename):
	    set path [lrange $path 1 [expr [llength $path]-2]]

	    set cumulative_path ""
	    set parent_folder_id $root_folder_id
	    foreach directory $path {
		append cumulative_path "$directory/"
		if (![info exists path_exists($cumulative_path)]) {
		    # check db
		    set folder_id [db_string get_folder_id {
			select nvl(content_item.get_id(:cumulative_path,:root_folder_id),0)
			from dual
		    }]
		    # If the folder doesn't exist, create it.
		    if { $folder_id == 0} {
			set folder_id [db_exec_plsql create_new_folder {
			    begin
				    :1 := static_page.new_folder (
					    name	=> :directory,
					    label	=> :directory,
					    parent_id	=> :parent_folder_id,
					    description	=> 'Static pages folder'
				    );
			    end;
			}]
			if { [string length $folder_add_proc] > 0 } {
			    uplevel "$folder_add_proc $cumulative_path $folder_id"
			}
		    } else {
			if { [string length $folder_unchanged_proc] > 0 } {
			    uplevel "$folder_unchanged_proc $cumulative_path $folder_id"
			}
		    }
		    set path_exists($cumulative_path) $folder_id
		    db_dml insert_path {
			insert into sp_extant_folders (session_id,folder_id)
			values (:sync_session_id,:folder_id)
		    }
		} else {
		    set folder_id $path_exists($cumulative_path)
		}
		set parent_folder_id $folder_id
	    }

	    # If the file is already in the db:
	    #    Fetch it from the db and load the file from the filesystem
	    #    If they differ:
	    #        Insert the filesystem version into the db.
	    # If the file isn't in the db:
	    #    Insert it.

	    # set sp_filename to the file path relative to the OpenACS
	    # install dir, this is what gets inserted into the db - DaveB
	    set sp_filename [sp_get_relative_file_path $file]

	    
	    if [db_0or1row check_db_for_page {
		select static_page_id from static_pages
		where filename = :sp_filename
	    }] {
		db_1row get_db_page {
		    select content as file_from_db from cr_revisions
		    where revision_id = content_item.get_live_revision(:static_page_id)
		}
		if { [catch {
		    set fp [open $file r]
		    set file_from_fs [read $fp]
		    close $fp
		} errmsg]} {
		    ad_return_error "Error reading file" \
			    "This error was encountered while reading $file: $errmsg"
		}
		if { $file_from_fs != $file_from_db } {
		    db_dml update_db_file {
			update cr_revisions set content = empty_blob()
			where revision_id = content_item.get_live_revision(:static_page_id)
			returning content into :1
		    } -blob_files [list $file]
			if { [string length $file_change_proc] > 0 } {
			    uplevel "$file_change_proc $file $static_page_id"
			}
		} else {
		    if { [string length $file_unchanged_proc] > 0 } {
			uplevel "$file_unchanged_proc $file $static_page_id"
		    }
		}
		db_dml insert_file {
		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)
		}
	    } else {
		# Try to extract a title:
		if { [catch {
		    set fp [open $file r]
		    set file_contents [read $fp]
		    close $fp
		} errmsg]} {
		    ad_return_error "Error reading file" \
			    "This error was encountered while reading $file: $errmsg"
		}

		if { ![regexp -nocase {<title.*?>(.+?)</title} $file_contents match page_title] } {
		    regexp {[^/]*$} $file page_title
		}

		# Insert into the db:
		# the Oracle driver apparently doesn't support passing BLOBs to
		# PL/SQL (or passing a BLOB from a file into a PL/SQL function),
		# so the PL/SQL call and the BLOB loading must be performed
		# seperately.  This is simple (get item_id from static_page.new(),
		# then update cr_revisions to insert the blob) but involved direct
		# manipulation of the cr_revisions table.
		set static_page_id [db_exec_plsql do_sp_new {
		    begin
			:1 := static_page.new(
				  filename => :sp_filename,
				  title => :page_title,
				  folder_id => :parent_folder_id
			      );
		    end;
		}]
		# Check if -blobs [list $file_contents] would be faster:
		db_dml insert_file_contents {
		    update cr_revisions set content = empty_blob()
		    where revision_id = content_item.get_live_revision(:static_page_id)
		    returning content into :1
		} -blob_files [list $file]
		if { [string length $file_add_proc] > 0 } {
		    uplevel "$file_add_proc $file $static_page_id"
		}
		db_dml insert_file {
		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)
		}
	    }
	}
    }

    # Clean up any files that are in the db but no longer in the filesystem:
    set package_id [ad_conn package_id]
    db_exec_plsql delete_old_files {
	begin
	    static_page.delete_stale_items(:sync_session_id,:package_id);

	    delete from sp_extant_folders where session_id = :sync_session_id;
	    delete from sp_extant_files where session_id = :sync_session_id;
	end;
    }
}

ad_proc -public sp_root_folder_id { package_id } {
    Returns the id of the root folder associated with package_id,
    creating one if necessary.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-23
} {
    # We must use db_exec_plsql rather than simply selecting from dual
    # because static_page.get_root_folder will do DML (to create the
    # folder) if it can't find a root folder.
    return [db_exec_plsql get_root_folder_id {
	begin
	    :1 := static_page.get_root_folder(:package_id);
	end;
    }]
}

ad_proc -public sp_change_matching_permissions {
    root_folder_id
    contained_string
    grant_or_revoke
} {
    Grant or revoke permissions on all files below root_folder_id
    whose filenames contain contained_string.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-23
} {
    if { $grant_or_revoke != "grant" && $grant_or_revoke != "revoke" } {
	ns_log Warning "sp_change_matching_permissions called with grant_or_revoke = $grant_or_revoke"
	return
    }

    db_exec_plsql grant_or_revoke_matching_permissions "
	    begin
	    for file_row in (
		    select static_page_id from static_pages
		    where folder_id in (
			    select folder_id from sp_folders
			    start with folder_id = :root_folder_id
			    connect by parent_id = prior folder_id)
		    and filename like '%${contained_string}%'
	    ) loop
		    acs_permission.${grant_or_revoke}_permission(
			    object_id => file_row.static_page_id,
			    grantee_id => acs.magic_object_id('the_public'),
			    privilege => 'general_comments_create'
		    );
	    end loop;
	    end;
    "
}

ad_proc -public sp_change_matching_display {
    root_folder_id
    contained_string
    show_full_comments_p
} {
    Set all files below root_folder_id whose filenames contain 
    contained_string to have comments either shown (full contents of
    comments are displayed on the page) or summarized (title line of
    comments are listed).

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-23
} {
    if { $show_full_comments_p != "t" && $show_full_comments_p != "f" } {
	ns_log Warning "sp_change_matching_permissions called with show_full_comments_p = $show_full_comments_p"
	return
    }

    db_foreach matching_static_page "
	select static_page_id from static_pages
	     where folder_id in (
		     select folder_id from sp_folders
		     start with folder_id = :root_folder_id
		     connect by parent_id = prior folder_id)
	     and filename like '%${contained_string}%'
    " {
	sp_flush_page $static_page_id
    }	

    db_dml show_or_summarize_comments_matching "
	    update static_pages set show_comments_p = :show_full_comments_p 
                where static_page_id in (
		    select static_page_id from static_pages
		    where folder_id in (
			    select folder_id from sp_folders
			    start with folder_id = :root_folder_id
			    connect by parent_id = prior folder_id)
		    and filename like '%${contained_string}%'
	        )
    "
}

ad_proc -private  sp_get_full_file_path { file } {
    takes a relative path and returns the full file path
} {
    set full_path [cr_fs_path STATIC_PAGES]
    append full_path $file
    return $full_path
}

ad_proc -private sp_get_relative_file_path { file } {
    Takes a full file path and returns the path relative to the
    static-page storage directory, usualyl /web/openacs/www/
} {
    set relative_path [string range $file [string length [cr_fs_path STATIC_PAGES]] end]

    ns_log notice "**[cr_fs_path STATIC_PAGES]**"
    ns_log notice "relative path:$relative_path"
    return $relative_path
}

 
ad_proc -private sp_get_page_info_query { page_id } {
    Returns a SQL query to get the page title and comment display policy.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-23
} {
    return [db_string get_page_info "select '{'||content_item.get_title($page_id)||'} '||decode(show_comments_p,'t',1,0) from static_pages where static_page_id = $page_id"]
}


ad_proc -private sp_get_page_id { filename } {
    Gets page_id
    @author Dave Bauer (dave@thedesignexperience.org)
    @creation-date 2001-07-30
} {
    return [list [db_string search_page "
    select static_page_id from static_pages sp, sp_folders spf 
               where filename='$filename' and sp.folder_id=spf.folder_id
               and package_id=[apm_package_id_from_key "static-pages"]" -default -1]]
}

ad_proc -public sp_flush_page { page_id } {
    Flushes the cache entry for a static page.  This should be done whenever the
    page title or show_comment_p setting change.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-23
} {
    util_memoize_flush [list [sp_get_page_info_query $page_id]]
}

ad_proc -public sp_serve_html_page { } {
    Registered proc to serve up static pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-01-23
} {
    set filename [ad_conn file]
    set sp_filename [sp_get_relative_file_path $filename]
    
    set page_id [util_memoize [list sp_get_page_id $sp_filename]]

    # If the page is in the db, serve it carefully; otherwise just dump it out.
    if { $page_id >= 0 } {
	set page_info [util_memoize [list sp_get_page_info_query $page_id]]

	# We only show the link here if the_public has 
	# general_comments_create privilege on the page.  Why the_public
	# rather than the current user?  Because we don't want admins to
	# be seeing "Add a comment" links on non-commentable pages.
	#
	set comment_link ""
	if { [ad_permission_p -user_id [acs_magic_object the_public] $page_id general_comments_create] } {

	    append comment_link "<center>[general_comments_create_link -object_name [lindex $page_info 0] $page_id [ad_conn url]]</center>"
	}
	append comment_link "[general_comments_get_comments -print_content_p [lindex $page_info 1] $page_id [ad_conn url]]"


	if { [catch {
	    set fp [open $filename r]
	    set file_contents [read $fp]
	    close $fp
	} errmsg] } {
	    ad_return_error "Error reading file" \
		    "This error was encountered while reading $filename: $errmsg"
	}

	# Tcl needs a case-insensitive [string first] function.
	#
	set body_close [string first "</body" [string tolower $file_contents]]
	if { $body_close >= 0 } {
	    doc_return 200 text/html "[string range $file_contents 0 [expr $body_close-1]]${comment_link}[string range $file_contents $body_close end]"
	} else {
	    doc_return 200 text/html "${file_contents}$comment_link"
	}
    } else {
	ns_returnfile 200 text/html $filename
    }
}

# Register the handler for each static page file extension.
rp_register_extension_handler html sp_serve_html_page
rp_register_extension_handler htm sp_serve_html_page
rp_register_extension_handler HTML sp_serve_html_page
rp_register_extension_handler HTM sp_serve_html_page
