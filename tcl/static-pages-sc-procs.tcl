ad_library { 
    static-pages/tcl/static-pages-sc-procs.tcl
    implements OpenFTS Search service contracts

    @author Dave Bauer (dave@thedesignexperience.org)
    @creation-date 2001-10-27
    @cvs-id $Id$
}

ad_proc static_page__datasource {
    object_id
} {
    Right now I am leaving the keywords blank
    in the future we should either extract them from the META keyword tag
    or allow assignment of cr_keywords to static_pages
    
    @author Dave Bauer (dave@thedesignexperience.org)

    @param object_id the object_id for which to generate the data

} {
    set path_stub [cr_fs_path STATIC_PAGES]
    
    db_0or1row sp_datasource "" -column_array datasource

    return [array get datasource]
}

ad_proc static_page__url {
    object_id
} {
    @author Dave Bauer (dave@thedesignexperience.org)
} {

    db_1row sp_url ""
    if {[string match /www/* $url]} { 
        # strip the /www off since its in pageroot
        return [ad_url][string range $url 4 end]
    } else {
        # find a package to match the url
        if {[regexp {/packages/([^/]*)/www/(.*)} $url match key stub]} { 
            set base [lindex [site_node::get_children -element url -package_key $key -node_id [site_node::get_element -url / -element node_id]] 0]
            if {![empty_string_p $base]} {
                return "[ad_url]$base$stub"
            }
        }
    }

    return $url
}
