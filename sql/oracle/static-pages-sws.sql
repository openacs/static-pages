--  packages/static-pages/sql/static-pages-sws.sql
--
--  /**
--   *  site-wide-search interface for static-pages.
--   *  
--   *  Copyright (C) 2001 ArsDigita Corporation
--   *  Author:  Brandoch Calef (bcalef@arsdigita.com)
--   *  Creation: 2001-02-02
--   *
--   *  $Id$
--   *  
--   *  This is free software distributed under the terms of the GNU Public
--   *  License.  Full text of the license is available from the GNU Project:
--   *  http://www.fsf.org/copyleft/gpl.html
--   **/

create or replace function sp_cr_revision_in_package_id (
     revision_id    in   cr_revisions.revision_id%TYPE
) return apm_packages.package_id%TYPE
is
    v_package_id     apm_packages.package_id%TYPE;
    v_item_id        cr_items.item_id%TYPE;
begin

   select package_id into v_package_id 
   from sp_folders spf, cr_revisions cr, cr_items ci
   where cr.revision_id = sp_cr_revision_in_package_id.revision_id
   and ci.item_id = cr.item_id
   and ci.parent_id = spf.folder_id;

   return v_package_id;

    exception 
        when no_data_found then
            return null;

end sp_cr_revision_in_package_id;
/



begin
    pot_service.register_object_type (
	package_key		=> 'static-pages',
	object_type		=> 'content_revision'
    );

    pot_service.set_obj_type_attr_value (
	package_key		=> 'static-pages',
	object_type		=> 'content_revision',
	attribute		=> 'display_page',
	attribute_value		=> 'page-visit?page_id='
    );    

    pot_service.set_obj_type_attr_value (
	package_key		=> 'static-pages',
	object_type		=> 'content_revision',
	attribute		=> 'cr_revision_in_package_id',
	attribute_value		=> 'sp_cr_revision_in_package_id'
    );    

    sws_service.update_content_obj_type_info ('content_revision');
end;
/
