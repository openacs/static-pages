# packages/static-pages/tcl/static-pages-procs.tcl
ad_library {
    Utilities for static pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-01-22
    @cvs-id $Id$
}


ad_proc -public sp_sync_cr_with_filesystem_scheduled {{}} {

    Sync the filesystem and the content repository in a scheduled
    procedure, rather than manually.  Calls sp_sync_cr_with_filesystem
    just like the www/admin/fs-scan-progress.tcl page does.

    <p>
    Note that if you have comments turned on, be <em>very carefull</em>
    running this, as the current implementation of
    sp_sync_cr_with_filesystem will <em>destroy</em> any user
    contributed comments on the file if you temporarily delete the
    file, then run that procedure.

    @author Andrew Piskorski (atp@piskorski.com)
    @creation-date 2002/09/12
} {
    set proc_name {sp_sync_cr_with_filesystem_scheduled}
    ns_log Notice "$proc_name: Starting."

    # sp_sync_cr_with_filesystem callbacks to fill file_items with info:

    proc sp_sch_old_item { path id } {}
    proc sp_sch_new_item { path id } {}
    proc sp_sch_changed_item { path id } {
        # The title may have changed:
        sp_flush_page $id
    }

    # TODO: We can have more than one package instance, so must decide
    # here WHICH package instance to run the sync for.  This should
    # probably be something configurable for each package instance from
    # the admin page, but for now we simply find and sync ALL package
    # instances: --atp@piskorski.com, 2002/09/12 14:02 EDT

    set package_key [sp_package_key_is]

    db_foreach each_apm_package_instance {
        select  package_id, instance_name
        from apm_packages
        where package_key = :package_key
        order by package_id
    } {
        set root_folder_id [sp_root_folder_id $package_id]
        set fs_root "[acs_root_dir][ad_parameter -package_id $package_id {fs_root}]"

        ns_log Notice "$proc_name: About to scan the filesystem for:  package_id '$package_id', instance_name '$instance_name', fs_root '$fs_root':"

        # If our call to sp_sync_cr_with_filesystem fails for some
        # reason, want to continue on trying the other package
        # instances:

        set sync_proc {sp_sync_cr_with_filesystem}
        if { [catch {
            set result [$sync_proc  -package_id $package_id \
                            -file_unchanged_proc    sp_sch_old_item \
                            -file_add_proc          sp_sch_new_item \
                            -file_change_proc       sp_sch_changed_item \
                            -folder_add_proc        sp_sch_new_item \
                            -folder_unchanged_proc  sp_sch_old_item \
                            $fs_root $root_folder_id]
        } errmsg] } {
            global errorInfo
            ns_log Error "$proc_name: For package_id: '$package_id', $sync_proc failed with error:\n${errorInfo}"
        } else {
            ns_log Notice "$proc_name: For package_id: '$package_id': $result"
        }

    } if_no_rows {
        ns_log Warning "$proc_name: NO package ids found for package key: '$package_key'."
    }

    ns_log Notice "$proc_name: Done."
}


ad_proc -public sp_sync_cr_with_filesystem {
    {
        -file_add_proc ""
        -file_change_proc ""
        -file_unchanged_proc ""
        -file_read_error_proc ""
        -folder_add_proc ""
        -folder_unchanged_proc ""
        -package_id ""
    }
    fs_root
    root_folder_id
    {
       static_page_regexp {}
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

    @param fs_root The starting path in the filesystem.  Files below this point will 
                   be scanned.

    @param root_folder_id The id of the root folder in the static-pages system (and in 
                          the content repository) obtained from 
                          <code>static_page.get_root_folder</code>.

    @param static_page_regexp A regexp to identify static pages.

    @param package_id Optionally, the package id of the Static Pages
    instance.  If not specified, determined from ad_conn.

    @author Andrew Piskorski (atp@piskorski.com)
    @creation-date 2001/08/27
} {
   if { [empty_string_p $package_id] } {
      set package_id [ad_conn package_id]
   }

   if { [catch { set return_val [sp_sync_cr_with_filesystem_internal \
           -file_add_proc          $file_add_proc         \
           -file_change_proc       $file_change_proc      \
           -file_unchanged_proc    $file_unchanged_proc   \
           -file_read_error_proc   $file_read_error_proc  \
           -folder_add_proc        $folder_add_proc       \
           -folder_unchanged_proc  $folder_unchanged_proc \
           -package_id             $package_id            \
           -stack_depth  2 \
           {return_mesg}  $fs_root  $root_folder_id  $static_page_regexp ]
   } result] } {
      # We caught an unexpected error, so clean up the mutex, and then
      # re-throw the exact same error:

      sp_sync_cr_with_filesystem_unlock $package_id

      global errorInfo
      error $result $errorInfo
   } else {
      return $return_mesg
   }
}


ad_proc -private sp_sync_cr_with_filesystem_unlock {package_id} {
   Unlocks the sp_sync_cr_with_filesystem_times variable - use upon
   abnormal termination of the sp_sync_cr_with_filesystem_internal
   stuff.  We have it as a separate proc here to make it convenient to
   call from within multiple different procedures.

   @author Andrew Piskorski (atp@piskorski.com)
   @creation-date 2001/08/27
} {
    set mutex [nsv_get . {sp_sync_cr_fs_mutex}]
    ns_mutex lock $mutex
    nsv_set {sp_sync_cr_fs_times} $package_id {}
    ns_mutex unlock $mutex
}


ad_proc -private sp_sync_cr_with_filesystem_internal { 
    {
        -file_add_proc ""
        -file_change_proc ""
        -file_unchanged_proc ""
        -file_read_error_proc ""
        -folder_add_proc ""
        -folder_unchanged_proc ""
        -package_id ""
        -stack_depth 1
    }
    return_mesg_var
    fs_root
    root_folder_id
    {
       static_page_regexp {}
    }
} {
   This procedure was originally named sp_sync_cr_with_filesystem
   procedure, but has been renamed and modified so that it can be
   wrapped inside the new sp_sync_cr_with_filesystem, to support the
   mutex locking.
   <p>
   We wrap it because at the end of this proc, we must set
   sp_sync_cr_with_filesystem_times($package_id) back to empty string.
   But if we hit some random untrapped error partway through, we'll
   never get there.  Therefore, we wrap this proc inside another, and
   have the wrapper proc catch any errors thrown by this proc, set the
   var back to empty string, then re-throw the error.
   <p>
   This procedure takes the exact same arguments as its
   sp_sync_cr_with_filesystem wrapper proc, except for the addition of
   return_mesg_var.
   <p>
   You should <em>never</em> call this procedure, except from
   sp_sync_cr_with_filesystem.

   @param return_mesg_var Name of variable in which to return text
   message, for presentation on a web page to the user.

   @param package_id <em>Must</em> be passed in, for this internal
   version of the proc.

   @author Brandoch Calef (bcalef@arsdigita.com)
   @author Andrew Piskorski (atp@piskorski.com)
   @creation-date 2001-02-07
} {
    set proc_name {sp_sync_cr_with_filesystem_internal}

    if { [empty_string_p $package_id] } {
        error "package_id '$package_id' is not valid."
    }
    upvar $return_mesg_var return_mesg
    set return_mesg {}


    # Make sure that only 1 copy of this proc per package instance
    # ever runs at once:

    set mutex [nsv_get . {sp_sync_cr_fs_mutex}]
    set nsv {sp_sync_cr_fs_times}

    # These multiple nsv operations need to all be atomic, so use a
    # mutex:

    ns_mutex lock $mutex

    if { ![nsv_array exists $nsv] } {
        ns_mutex unlock $mutex
        error "nsv array '$nsv' does not exist!"
    } elseif { ![nsv_exists $nsv $package_id] } {
        # The package_id isn't in the array yet at all, so another copy
        # is not running.
        set other_start_time {}
    } else {
        set other_start_time [nsv_get sp_sync_cr_fs_times $package_id]
    }

    if { [empty_string_p $other_start_time] } {
        # We're ok, no other copy is running.
        nsv_set $nsv $package_id [ns_time]
        set run_p 1
    } else {
        set run_p 0
    }

    ns_mutex unlock $mutex

    if { ! $run_p } {
        # Another copy is running, must abort:
        set time_diff [expr [ns_time] -  $other_start_time]

        set other_time_pretty [ns_httptime $other_start_time]
        # Could also use: [clock format [clock seconds]]

        set mesg "sp_sync_cr_with_filesystem: Already running. sp_sync_cr_fs_times($package_id) == $other_time_pretty, $time_diff seconds ago."
        ns_log Warning $mesg

        set return_mesg "Another copy of this procedure is already running for
       this package instance.  It started running $time_diff seconds
       ago, at $other_time_pretty.  Only one copy may run at a time.
       Please wait and then try again."

        # Whether you actually see this happen depends whether the
        # second thread running this proc gets scheduled or not before
        # the first one completes.  If your machine is slow enough, or
        # you have enough threads going at once, you will see it.
        # --atp@piskorski.com, 2002/12/16 03:57 EST

        return 0
    }


    set sync_session_id [db_nextval sp_session_id_seq]

    set fs_trimmed [string trimright $fs_root "/"]
    set fs_trimmed_length [string length $fs_trimmed]

    set static_page_regexp "\\.[join [split [string trim [ad_parameter -package_id $package_id AllowedExtensions]] " "] "$|\\."]$"

    # TODO: What happens if at some point, an Admin CHANGES the
    # fs_root parameter for a Static Pages package instance?  BAD
    # THINGS, I suspect.  We're probably invisibly orphaning content
    # inside the Content Repository.  Look into this.  For now, simply
    # DO NOT change the fs_root of an already in use Static Pages
    # package instance.
    # --atp@piskorski.com, 2002/09/15 10:03 EDT

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
			set folder_id [db_exec_plsql create_new_folder {}]
			if { [string length $folder_add_proc] > 0 } {
			    uplevel $stack_depth "$folder_add_proc $cumulative_path $folder_id"
			}
		    } else {
			if { [string length $folder_unchanged_proc] > 0 } {
			    uplevel $stack_depth "$folder_unchanged_proc $cumulative_path $folder_id"
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
	    set mtime_from_fs [file mtime $file]

   	    if [db_0or1row check_db_for_page {
		select static_page_id, mtime as mtime_from_db from static_pages
		where filename = :sp_filename
	    }] {

	       if { [catch {
		    set fp [open $file r]
		    set file_from_fs [read $fp]
		    close $fp
		} errmsg]} {
                    # Log and return an appropriate message, then
                    # continue on trying to process the other files.
                    # We do NOT want to abort the whole scan just
                    # because one file had problems:
                    # --atp@piskorski.com, 2002/09/12 16:49 EDT

                    set mesg "$proc_name: Error reading file: '$file':  [ns_quotehtml $errmsg]"
                    ns_log Error $mesg
                    if { ![empty_string_p $file_read_error_proc] } {
                        ns_log Notice "$proc_name: about to run file_read_error_proc:"
                        uplevel $stack_depth [list $file_read_error_proc $file $static_page_id $mesg]
                    }
                    continue
		}
	    
		set file_updated 0

		set storage_type [db_string get_storage_type ""]

		switch $storage_type {
		    "file" {
			if {$mtime_from_fs != $mtime_from_db} {
			    set file_updated 1	    
			}
		    }
			
		     "lob" {
			    db_1row get_db_page {
				select content as file_from_db from cr_revisions
				where revision_id = content_item.get_live_revision(:static_page_id)
			    }
			 if {$file_from_db != $file_from_fs} {
			     set file_updated 1
			 }
		     }
		}
		
		if {$file_updated == 1} {
		    db_dml update_db_file {
			update cr_revisions set content = empty_blob()
			where revision_id = content_item.get_live_revision(:static_page_id)
			returning content into :1
		    } -blob_files [list $file]
		    if {$storage_type=="file"} {

			db_dml update_static_page {
			    update static_pages set mtime = :mtime_from_fs
			    where  static_page_id = :static_page_id
			}
		    }
			if { [string length $file_change_proc] > 0 } {
			    uplevel $stack_depth "$file_change_proc $file $static_page_id"
			}
		} else {
		    if { [string length $file_unchanged_proc] > 0 } {
			uplevel $stack_depth "$file_unchanged_proc $file $static_page_id"
		    }
		}
		db_dml insert_file {
		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)
		}
	    } else {
                # The file is NOT in the db yet at all:

		# Try to extract a title:
		if { [catch {
		    set fp [open $file r]
		    set file_contents [read $fp]
		    close $fp
		} errmsg]} {
                    # Log and return an appropriate message, then
                    # continue on trying to process the other files.
                    # We do NOT want to abort the whole scan just
                    # because one file had problems:
                    # --atp@piskorski.com, 2002/09/12 16:49 EDT

                    set mesg "$proc_name: Error reading file: '$file':  [ns_quotehtml $errmsg]"
                    ns_log Error $mesg
                    if { ![empty_string_p $file_read_error_proc] } {
                        ns_log Notice "$proc_name: about to run file_read_error_proc:"
                        uplevel $stack_depth [list $file_read_error_proc $file $static_page_id $mesg]
                    }
                    continue
		}

                # TODO:  This is very HTML specific:  --atp@piskorski.com, 2001/08/13 21:58 EDT
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

                # If you run two copies of sp_sync_cr_with_filesystem
                # at once, you CAN get "ORA-00001: unique constraint
                # (CR_ITEMS_UNIQUE_NAME) violated" errors here when
                # calling static_page.new - thus the addition of mutex
                # locking.  --atp@piskorski.com, 2001/08/27 01:20 EDT

                set mime_type [sp_maybe_create_new_mime_type $sp_filename]
		set static_page_id [db_exec_plsql do_sp_new {}]
		# Check if -blobs [list $file_contents] would be faster:
		db_dml insert_file_contents {} -blob_files [list $file]

		if { [string length $file_add_proc] > 0 } {
		    uplevel $stack_depth "$file_add_proc $file $static_page_id"
		}
		db_dml insert_file {
		    insert into sp_extant_files (session_id,static_page_id)
		    values (:sync_session_id,:static_page_id)
		}
	    }
	}
    }

    # TODO: This is very wrong.  Should NEVER just delete all content! 
    # Note that the canonical content of the file itself lives in the 
    # fileystem and can easily be re-imported to the database, but 
    # this ALSO blindly deletes all user-contributed comments which 
    # point to the file! 
    # 
    # See also: http://openacs.org/bboard/q-and-a-fetch-msg.tcl?msg_id=0002U2 
    # 
    # --atp@piskorski.com, 2001/08/13 15:07 EDT 
 
    # Clean up any files that are in the db but no longer in the filesystem:

    # TODO: Why are we doing these two deletes after calling
    # static_page.delete_stale_items?
    # --atp@piskorski.com, 2001/08/23 02:20 EDT 

    db_exec_plsql delete_old_files {
	begin
	    static_page.delete_stale_items(:sync_session_id,:package_id);

	    delete from sp_extant_folders where session_id = :sync_session_id;
	    delete from sp_extant_files where session_id = :sync_session_id;
	end;
    }

    # TODO: We should have a sp_deleted_item hook just like we do for
    # new, old, and changd items.  As it is now, we delete the file
    # out of the database but provide NO notification that we did so.
    # --atp@piskorski.com, 2002/12/12 12:43 EST

    sp_sync_cr_with_filesystem_unlock $package_id
    set return_mesg "Done."
    return 0
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
    Returns a two item list of the page_id and the static-pages
    package_id it belongs to.

    @author Dave Bauer (dave@thedesignexperience.org)
    @creation-date 2001-07-30
} {
    # This package is no longer a singleton, so can't use
    # apm_package_id_from_key here: --atp@piskorski.com, 2001/08/26
    # 22:37 EDT

    set package_key [sp_package_key_is]
    if { [db_0or1row page_and_package_ids {}] } {
        set results [list $static_page_id $package_id]
    } else {
        set results [list -1 -1]
    }

    return $results
}

ad_proc -public sp_flush_page { page_id } {
    Flushes the cache entry for a static page.  This should be done whenever the
    page title or show_comment_p setting change.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-23
} {
    util_memoize_flush [list sp_get_page_info_query $page_id]
}


ad_proc sp_maybe_create_new_mime_type {
    file_name
} {
    This proc should be identical to fs_maybe_create_new_mime_type
    from the file-storage package.  However, we don't want to depend
    on file-storage being loaded, so if it isn't, define our own
    implementation here.  --atp@piskorski.com, 2002/12/15 19:34 EST

    <p>
    The content repository expects the MIME type to already be defined
    when you upload content.  We use this procedure to add a new type
    when we encounter something we haven't seen before.

    @author Andrew Piskorski (atp@piskorski.com)
    @creation-date 2002-12-15
} {
    set proc_name {sp_maybe_create_new_mime_type}
    set func {fs_maybe_create_new_mime_type}

    if { [nsv_exists api_proc_doc $func] ||
         ![empty_string_p [namespace eval :: [list info procs $func]]]
     } {
        # The file-storage version of this proc exists, use it:
        return [eval [list $func $file_name]]

    } else {
        # Fall back to local implementation:

        set file_extension [string trimleft [file extension $file_name] "."]
        if {[empty_string_p $file_extension]} {
            return "*/*"
        }

        # TODO: This insert may fail due to a race condition.  Should be
        # locking the cr_mime_types table first:
        # --atp@piskorski.com, 2001/08/23 20:20 EDT

        if {![db_0or1row select_mime_type {
            select mime_type
            from cr_mime_types
            where file_extension = :file_extension
        }]} {
            # A mime type for this file extension does not exist
            # in the database.  Check to see AOLServer can 
            # generate a mime type.

            set mime_type [ns_guesstype $file_name]
            
            # Note: If AOLServer can't determine a mime type, 
            # ns_guesstype will return */*. We still record
            # a mime type for this file extension.  At a later
            # date, the mime type for the file extension may be
            # updated and, as a result, the files with that
            # file extension will be associated with the
            # proper mime types.

            db_dml new_mime_type {
                insert into cr_mime_types
                (mime_type, file_extension)
                values
                (:mime_type, :file_extension)
            }
        }
        return $mime_type
    }
}


ad_proc -public sp_package_key_is {} {
   Simply returns the package key string for this package.
   @author Andrew Piskorski (atp@piskorski.com)
   @creation-date 2001/08/26
} {
   # TODO: Might want to have this pull and cache the actual key from
   # the database.
   return {static-pages}
}


ad_proc -private sp_package_url {package_key} {
   <p>Given a package key, return a URL of a mounted
   package instance. If there is more than one instance
   of the package mounted, the one with the lowest
   <code>package_id</code> will be returned. If the
   package is not instantiated or not mounted anywhere,
   an error is raised. The proc is meant to be memoized.
   </p>
} {
    set proc_name {sp_package_url}

    set found_p [db_0or1row get_any_package_instance {
        select min(package_id) as package_id
        from apm_packages
        where package_key = :package_key
    }]

    if { !$found_p } {
        error "$proc_name: the '$package_key' package is not instantiated."
    }

    set found_p [db_0or1row get_mount_point {}]

    if { !$found_p } {
        error "$proc_name: the '$package_key' package is not mounted."
    }

    return $url
}


ad_proc -public sp_serve_html_page { } {
    Registered proc to serve up static pages.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-01-23
} {
    set filename [ad_conn file]
    set sp_filename [sp_get_relative_file_path $filename]

    # In order to determine per-instance parameters like
    # TemplatingEnabledP, need to know the package_id of the
    # static-pages instance where this page is located, which is
    # likely NOT the package_id returned by [ad_conn package_id]:

    foreach [list page_id package_id] \
        [util_memoize [list sp_get_page_id $sp_filename]] { break }

    set file [ad_conn file]
    ad_conn -set subsite_id [site_node_closest_ancestor_package "acs-subsite"]

    # If the page is in the db, serve it carefully; otherwise just dump it out.
    if { $page_id >= 0 } {
        set page_info [util_memoize [list sp_get_page_info_query $page_id]]

        # TODO: Below, what if we only allow registered users to make
        # comments?  Or some smaller group of users?  What then?
        # --atp@piskorski.com, 2001/08/22 23:09 EDT

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
            set body "[string range $file_contents 0 [expr $body_close-1]]${comment_link}[string range $file_contents $body_close end]"
        } else {
            set body "${file_contents}$comment_link"
        }
    } else {
        set body [template::util::read_file $file]
    }

    set templating_enabled [ad_parameter -package_id $package_id TemplatingEnabledP]
    if { ![empty_string_p $templating_enabled] && $templating_enabled } {
	# Strip out the <body>..</body> part as page will now be part of a master template
	set headers ""
	set sp_scripts ""
	set title ""
	if {[regexp -nocase {(.*?)<body.*?>(.*)</body.*?>} $body match headers bodyless]} {
	    set body $bodyless
	}   
	# Get 0 or 1 <title>...</title> data to pass up to master template html headers
	regexp -nocase {<title.*?>(.*?)</title.*?>} $headers match title
	
	# Get 0 or more <script>...</script> tags to pass up to master template html headers
	while {[regexp -nocase {(<script.*?>.*?</script.*?>)(.*$)} $headers match ascript headers]} {
	    append sp_scripts "\n$ascript"
	} 
	set file_mtime [clock format [file mtime $file]]    
	set result [template::adp_parse [acs_root_dir]/[ad_parameter -package_id $package_id TemplatePath] [list body $body sp_scripts $sp_scripts title $title file_mtime $file_mtime]]
	ns_return 200 text/html $result     
    } else {
	ns_return 200 text/html $body
    }
}


ad_proc -private sp_register_extension {} {
    Register the handler for each static page file extension.
} {
    set proc_name {sp_register_extension}

    set package_key [sp_package_key_is]
    set package_ids [db_list all_static_pages_package_instances {
        select package_id
        from apm_packages
        where package_key = :package_key
    }]

    # Generate unique list of all file-name extensions used by all
    # package instances:

    array set extensions_arr [list]
    foreach package_id $package_ids {
        foreach extension [split [string tolower [string trim [ad_parameter -package_id $package_id AllowedExtensions]]] " "] {
            set extensions_arr($extension) {}
        }
    }

    foreach extension [array names extensions_arr] {
        # TODO: Are we supposed to use the sp_serve_html_page proc for
        # ALL file-name extensions, even if they're PDF or MS Word
        # documents?  I think not!  Need a better way to map file-name
        # extensions to proper static-pages extension handler procs.
        # --atp@piskorski.com, 2002/12/11 22:55 EST

        if { [regexp {htm} $extension] } {
            set handler_proc {sp_serve_html_page}
            rp_register_extension_handler $extension $handler_proc
            rp_register_extension_handler [string toupper $extension] $handler_proc
        } else {
            ns_log Notice "$proc_name:  NOT registering any proc to handle files with extension '$extension'."

            # TODO: Add a PDF or other extension handler?  Necessary
            # only if you want to be able to make comments on non-HTML
            # files, I think.
            # --atp@piskorski.com, 2002/12/11 22:55 EST
        }
    }
}
