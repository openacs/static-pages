--  packages/static-pages/sql/static-pages-sws-drop.sql
--
--  /**
--   *  Remove site-wide-search interface for static-pages.
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


begin
    pot_service.delete_obj_type_attr_value (
	package_key		=> 'static-pages',
	object_type		=> 'content_revision',
	attribute		=> 'cr_revision_in_package_id'
    );    

    pot_service.delete_obj_type_attr_value (
	package_key		=> 'static-pages',
	object_type		=> 'content_revision',
	attribute		=> 'display_page'
    );    

    pot_service.unregister_object_type (
	package_key		=> 'static-pages',
	object_type		=> 'content_revision'
    );

    sws_service.update_content_obj_type_info ('content_revision');
end;
/

drop function sp_cr_revision_in_package_id;


