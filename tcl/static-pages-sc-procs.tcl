# static-pages/tcl/static-pages-sc-procs.tcl
# implements OpenFTS Search service contracts
# Dave Bauer dave@thedesignexperience.org
# 2001-10-27

# Right now I am leaving the keywords blank
# in the future we should either extract them from the META keyword tag
# or allow assignment of cr_keywords to static_pages

ad_proc static_page__datasource {
    object_id
} {
    @author Dave Bauer
} {

    set path_stub [cr_fs_path STATIC_PAGES]
    
    db_0or1row sp_datasource ""     -column_array datasource

    return [array get datasource]
}

ad_proc static_page__url {
    object_id
} {
    @author Dave Bauer
} {

    db_1row sp_url ""
    return "${url}"
}
