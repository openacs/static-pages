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


select pot_service__delete_obj_type_attr_value (
	'static-pages',			-- package_key
	'content_revision',		-- object_type
	'cr_revision_in_package_id'	-- attribute
    );    

select pot_service__delete_obj_type_attr_value (
	'static-pages',			-- package_key
	'content_revision',		-- object_type
	'display_page'			-- attribute
    );    

select pot_service__unregister_object_type (
	'static-pages',			-- package_key
	'content_revision'		-- object_type
    );

select sws_service__update_content_obj_type_info ('content_revision');

drop function sp_cr_revision_in_package_id(integer);



