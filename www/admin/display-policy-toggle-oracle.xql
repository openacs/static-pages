<?xml version="1.0"?>
<queryset>
   <rdbms><type>oracle</type><version>8.1.6</version></rdbms>
<fullquery name="toggle_display_policy">      
      <querytext>
      
    update static_pages
        set show_comments_p = decode(show_comments_p,'t','f','t')
        where static_page_id = :item_id
      </querytext>
</fullquery>

 
</queryset>
