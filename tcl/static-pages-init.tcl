# setup the STATIC_PAGES location for CR_LOCATIONS so that all paths
# stored in the db are relative to the OpenACS installation dir

if { ![nsv_exists CR_LOCATIONS STATIC_PAGES] } {
    # Since we allow the fs_root of static-pages package instances to
    # be beneath the packages/ directory, this must now be relative to
    # the server root (e.g., "/web/mysite/"), not the web root (e.g.,
    # "/web/mysite/www/"):  --atp@piskorski.com, 2002/12/12 16:17 EST

    nsv_set CR_LOCATIONS STATIC_PAGES "[file dirname [string trimright [ns_info tcllib] "/"]]"
}


# Use these to insure that only 1 copy of sp_sync_cr_with_filesystem
# per Static Pages package instance ever runs at once.  For each
# package_id in the array, empty string means not running, a string
# means is curretnly running, and the string will give the time the
# proc started running:

ns_share -init { array set sp_sync_cr_with_filesystem_times {} } sp_sync_cr_with_filesystem_times

ns_share -init { set sp_sync_cr_with_filesystem_mutex [ns_mutex create] } sp_sync_cr_with_filesystem_mutex


# Register the handler for each static page file extension.
sp_register_extension


ns_log notice "static-pages-init.tcl loaded"
