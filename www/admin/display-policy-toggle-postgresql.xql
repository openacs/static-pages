<?xml version="1.0"?>
<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>
<fullquery name="toggle_display_policy">      
      <querytext>
      
    update static_pages
        set show_comments_p = (CASE when show_comments_p=TRUE then FALSE else TRUE end)
        where static_page_id = :item_id
      </querytext>
</fullquery>

 
</queryset>
