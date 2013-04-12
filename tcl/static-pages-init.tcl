ns_log Notice "Loading packages/tcl/static-pages-init.tcl"

# setup the STATIC_PAGES location for CR_LOCATIONS so that all paths
# stored in the db are relative to the OpenACS installation dir

if { ![nsv_exists CR_LOCATIONS STATIC_PAGES] } {
    # Since we allow the fs_root of static-pages package instances to
    # be beneath the packages/ directory, this must now be relative to
    # the server root (e.g., "/web/mysite/"), not the web root (e.g.,
    # "/web/mysite/www/"):  --atp@piskorski.com, 2002/12/12 16:17 EST

    nsv_set CR_LOCATIONS STATIC_PAGES "[file dirname [string trimright $::acs::tcllib "/"]]"
}


# Use these to insure that only 1 copy of sp_sync_cr_with_filesystem
# per Static Pages package instance ever runs at once.  For each
# package_id in the array, empty string means not running, a string
# means is curretnly running, and the string will give the time the
# proc started running:

set nsv {sp_sync_cr_fs_times}
if { ![nsv_array exists $nsv] } {
    nsv_array set $nsv [list]
    #nsv_set $nsv foo bar ; nsv_unset $nsv foo
}

set key {sp_sync_cr_fs_mutex}
if { ![nsv_exists . $key] } {
    nsv_set . $key [ns_mutex create]
}


# Register the handler for each static page file extension.
sp_register_extension


# Once per night, at 4 am:
#ad_schedule_proc -thread t -schedule_proc ns_schedule_daily [list 04 00] sp_sync_cr_with_filesystem_scheduled



