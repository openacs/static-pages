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

create function sp_cr_revision_in_package_id (
     integer		-- revision_id    in   cr_revisions.revision_id%TYPE
) returns integer as '
declare
	p_revision_id alias for $1;	
    v_package_id     apm_packages.package_id%TYPE;
    -- v_item_id        cr_items.item_id%TYPE;
begin
   select package_id into v_package_id
   from sp_folders spf, cr_revisions cr, cr_items ci
   where cr.revision_id = p_revision_id
   and ci.item_id = cr.item_id
   and ci.parent_id = spf.folder_id;

   if not found then
        return null;
   end if;
   return v_package_id;

end;' language 'plpgsql';




select pot_service__register_object_type (
	'static-pages',		-- package_key
	'content_revision'	-- object_type
    );

select pot_service__set_obj_type_attr_value (
	'static-pages',			-- package_key
	'content_revision',		-- object_type
	'display_page',			-- attribute
	'page-visit?page_id='		-- attribute_value
    );    

select pot_service__set_obj_type_attr_value (
	'static-pages',			-- package_key
	'content_revision',		-- object_type
	'cr_revision_in_package_id',	-- attribute
	'sp_cr_revision_in_package_id'	-- attribute_value
    );    

select sws_service__update_content_obj_type_info ('content_revision');

