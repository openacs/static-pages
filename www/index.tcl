# packages/static-pages/www/index.tcl
ad_page_contract {
    If static pages fs_root is set to a directory which
    exists in www/ then display the static files at the
    fs_root for this instance.  Otherwise simply redirect to
    admin.

    this makes it possible to eg. create a static doc tree for
    a community mounted at example.com/c1 and if fs_root is set
    to /www/c1/static and static pages is mounted at example/c1/static 
    then the files in the static tree can simply be browsed.

    It should probably check for a /www/c1/static/index.html or index.htm page
    though.

    @author Jeff Davis (davis@xarg.net)
    @creation-date 2001-02-23
    @cvs-id $Id$
} {
}

# if the mount point is the package_url and there is a directory there then show 
# the files in the filesystem otherwise jump to the admin page
set fs_root [string trimright [parameter::get -parameter fs_root] /]

if {"$fs_root/" eq "/www[ad_conn package_url]"
    && [file isdirectory "[acs_root_dir]$fs_root"]
} {
    set listing [rp_html_directory_listing [acs_root_dir]$fs_root]
} else {
    ad_returnredirect "admin/"
}

