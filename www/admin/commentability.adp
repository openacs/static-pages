<master>
<property name="doc(title)">@title;literal@</property>
<property name="context">@context;literal@</property>

<p>Click to toggle.</p>

<table>
<multiple name=dir_tree>
 <tr>
  <td>@dir_tree.spaces;noquote@@dir_tree.folder_name@</td>
  <td><a href="commentability-toggle.tcl?item_id=@dir_tree.folder_id@&recurse=t">@dir_tree.folder_permission@</a></td> <td></td>
 </tr>
 <group column="folder_id">
  <if @dir_tree.filename@ not nil>
   <tr>
    <td>@dir_tree.spaces;noquote@&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="../page-visit?page_id=@dir_tree.static_page_id@">@dir_tree.filename@</a></td>
    <td><a href="commentability-toggle.tcl?item_id=@dir_tree.static_page_id@&recurse=f">@dir_tree.file_permission@</a></td>
    <td><a href="display-policy-toggle.tcl?item_id=@dir_tree.static_page_id@">@dir_tree.display_policy@</a></td>
   </tr>
  </if>
 </group>
</multiple>
</table>

<br>
<form action="commentability-contain">
Or change all files whose full paths contain:
<table>
<tr><td colspan="3"><input type="text" size="80" maxlength="80"
name="contained_string" value="">
<br><font size=-1>
For example, <code>w/doc</code> will match <code>@acs_root@/www/doc/foobar.html</code>
and <code>@acs_root@/www/cow/doctor.html</code>.
</font></td></tr>
<td><input type="radio" name="change_option" value="grant_p_1" checked>&nbsp;&nbsp;Commentable
<br><input type="radio" name="change_option" value="grant_p_0">&nbsp;&nbsp;Not commentable </td>
<td><input type="radio" name="change_option" value="show_p_1">&nbsp;&nbsp;Comments displayed
<br><input type="radio" name="change_option" value="show_p_0">&nbsp;&nbsp;Comments summarized</td>
<td><input type="submit" value="Change"></td>
</tr>
</table>
</form>
