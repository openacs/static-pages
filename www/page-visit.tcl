# packages/static-pages/www/page-visit.tcl
ad_page_contract {
    Redirect to the indicated page_id.  This page is used by
    site-wide-search.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-03-05
    @cvs-id $Id$
} {
    page_id:integer
}

if { ![db_0or1row sp_path { select filename from static_pages where static_page_id = :page_id }] } {
    ad_return_error "Page not found" "The page requested could not be found."
    ad_script_abort
}

# The filename must begin "[acs_root_dir]/www" to be valid.  These leading
# characters will then be stripped off to produce the URL.
# DaveB: not anymore! We chop off that part and just stuff the relative
# path in the database to allow leaving the static-pages in the filesystem
#
#if { [string first "[acs_root_dir]/www" $filename] != 0 } {
#    ad_return_error "Error in filename" "This page has an invalid filename."
#}


#ad_returnredirect $filename


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

    set found_p [db_0or1row get_mount_point {
        select site_node.url(min(node_id)) as url
        from site_nodes
        where object_id = :package_id
    }]

    if { !$found_p } {
        error "$proc_name: the '$package_key' package is not mounted."
    }

    return $url
}


# There are two possiblities: Either the static page is beneath the
# site global www/ directory (and the filename starts "/www/"), or it
# is beneath one of the package www directories (and the filename
# starts "/packages/":

if { [string first "/www/" $filename] == 0 } {
    set redirect_to [string range $filename [string length "/www/"] end]
} elseif { [regexp "^/packages/(\[^/\]+)" $filename match package_dir] } {
   # TODO: We are assuming that the package directory name $package_dir
   # is in fact always the package key.  Is this really true?

   if { ! [regexp "^/packages/$package_dir/www/(.+)" $filename match url_part] } {
      ad_return_error "Error in filename" "This page has an invalid filename: '$filename'."
   }

   set redirect_to "[sp_package_url $package_dir]$url_part"
} else {
   ad_return_error "Error in filename" "This page has an invalid filename: '$filename'."
   return
}

ns_log Notice "atp:  redirect_to: '$redirect_to'  filename: '$redirect_to'"
ad_returnredirect $redirect_to
