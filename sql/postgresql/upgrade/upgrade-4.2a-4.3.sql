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

\i static-page-pb.sql
