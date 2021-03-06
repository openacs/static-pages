--
-- @cvs-id $Id$ 
--


-- Note: Slight differences will exist between an old upgraded
-- installation and a newly created one:
--
-- For an old upgraded installation, the one old package instance will
-- have the OLD 'sp_root' folder name rather than the new
-- 'sp_root_package_id_PACKAGEID' style name, but this should not
-- matter.  The names are still all unique from each other, which is
-- all that matters.  --atp@piskorski.com, 2002/12/12 13:59 EST

@static-page-ph.sql
@static-page-pb.sql

update apm_package_types  set singleton_p = 'f'
where package_key = 'static-pages' ;
commit;

-- This converts any old static_pages.filename values in the db to be
-- relative to the server rather than page root.  See also comment in
-- tcl/static-pages-init.tcl re. CR_LOCATIONS STATIC_PAGES:
-- --atp@piskorski.com, 2002/12/12 16:17 EST

update static_pages  set filename = '/www' || filename;


-- Note: If you want to check that the non-html mime types are being
-- set correctly, try this query: --atp@piskorski.com, 2002/12/15
-- 22:19 EST
-- 
-- column filename  format a60
-- select  s.folder_id  ,s.static_page_id
--   ,c.item_id
--   ,s.filename
--   ,r.mime_type
-- from static_pages s, cr_items c
--   ,cr_revisions r
-- where s.static_page_id = c.item_id
--   and s.folder_id = c.parent_id
--   and c.item_id = r.item_id
--   --and r.mime_type != 'text/html'
-- order by s.folder_id, s.filename ;
