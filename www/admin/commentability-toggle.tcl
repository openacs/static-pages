# packages/static-pages/www/admin/commentability-toggle.tcl
ad_page_contract {
    Toggle commentability status of an object.

    @author Brandoch Calef (bcalef@arsdigita.com)
    @creation-date 2001-02-20
    @cvs-id $Id$
} {
    item_id:integer
    recurse:boolean
}

if [permission::permission_p -party_id [acs_magic_object the_public] -object_id $item_id -privilege general_comments_create] {
    db_exec_plsql revoke_commentability {
	begin
	    static_page.revoke_permission(:item_id,acs.magic_object_id('the_public'),'general_comments_create',
	        :recurse);
	end;
    }
} else {
    db_exec_plsql grant_commentability {
	begin
	    static_page.grant_permission(:item_id,acs.magic_object_id('the_public'),'general_comments_create',
                :recurse);
	end;
    }
}

ad_returnredirect commentability

