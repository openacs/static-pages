<?xml version="1.0"?>

<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="revoke_commentability">      
      <querytext>

	    select static_page__revoke_permission(:item_id,acs__magic_object_id('the_public'),
	    'general_comments_create', :recurse)
    
      </querytext>
</fullquery>

 
<fullquery name="grant_commentability">      
      <querytext>

	    select static_page__grant_permission(:item_id,acs__magic_object_id('the_public'),
		'general_comments_create', :recurse)
    
      </querytext>
</fullquery>

 
</queryset>
