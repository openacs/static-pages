# setup the STATIC_PAGES location for CR_LOCATIONS so that all paths
# stored in the db are relative to the OpenACS installation dir

if ![nsv_exists CR_LOCATIONS STATIC_PAGES] {
    nsv_set CR_LOCATIONS STATIC_PAGES "[file dirname [string trimright [ns_info tcllib] "/"]]/www"
}

if ![nsv_exists static_pages package_id] {
    nsv_set static_pages package_id [apm_package_id_from_key static-pages]
}

ns_log notice "static-pages-init.tcl loaded"
    