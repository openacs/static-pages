<?xml version="1.0"?>

<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="static_page__datasource.sp_datasource">
      <querytext>
       	select r.revision_id as object_id,
	       r.title as title,
	       '$path_stub' || r.content as content,
	       'text/html' as mime,
	       '' as keywords,
	       'file' as storage_type
	from cr_revisions r
	       where revision_id = :object_id
      </querytext>
</fullquery>

<fullquery name="static_page__url.sp_url">
	<querytext>
        select r.content as url
        from cr_revisions r
             where revision_id = :object_id
	</querytext>
</fullquery>

</queryset>
