<?xml version="1.0"?>

<queryset>
   <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

<fullquery name="revoke_commentability">      
      <querytext>
      
	begin
	    static_page.revoke_permission(:item_id,acs.magic_object_id('the_public'),'general_comments_create',
	        :recurse);
	end;
    
      </querytext>
</fullquery>

 
<fullquery name="grant_commentability">      
      <querytext>
      
	begin
	    static_page.grant_permission(:item_id,acs.magic_object_id('the_public'),'general_comments_create',
                :recurse);
	end;
    
      </querytext>
</fullquery>

 
</queryset>
