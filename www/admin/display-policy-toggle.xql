<?xml version="1.0"?>
<queryset>

<fullquery name="toggle_display_policy">      
      <querytext>
      FIX ME DECODE (USE SQL92 CASE) 
    update static_pages
        set show_comments_p = decode(show_comments_p,'t','f','t')
        where static_page_id = :item_id

      </querytext>
</fullquery>

 
</queryset>
