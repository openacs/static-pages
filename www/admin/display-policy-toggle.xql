<?xml version="1.0"?>
<queryset>

<fullquery name="toggle_display_policy">      
      <querytext>
    update static_pages
        set show_comments_p = (CASE WHEN show_comments_p=TRUE THEN FALSE ELSE TRUE END)
        where static_page_id = :item_id

      </querytext>
</fullquery>

 
</queryset>
