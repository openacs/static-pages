# setup the STATIC_PAGES location for CR_LOCATIONS so that all paths
# stored in the db are relative to the OpenACS installation dir

if ![nsv_exists CR_LOCATIONS STATIC_PAGES] {
    nsv_set CR_LOCATIONS STATIC_PAGES "[file dirname [string trimright [ns_info tcllib] "/"]]/www"
}

if ![nsv_exists static_pages package_id] {
    nsv_set static_pages package_id [apm_package_id_from_key static-pages]
}


# Use these to insure that only 1 copy of sp_sync_cr_with_filesystem
# per Static Pages package instance ever runs at once.  For each
# package_id in the array, empty string means not running, a string
# means is curretnly running, and the string will give the time the
# proc started running:

ns_share -init { array set sp_sync_cr_with_filesystem_times {} } sp_sync_cr_with_filesystem_times

ns_share -init { set sp_sync_cr_with_filesystem_mutex [ns_mutex create] } sp_sync_cr_with_filesystem_mutex



ns_log notice "static-pages-init.tcl loaded"
