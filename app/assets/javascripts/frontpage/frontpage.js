
var onMenu = 0;
function switchBillTab(to, title) {
    allTabs = Element.childElements('bill_tabs')
    allTabs.each(function(t) {
       Element.hide(t);
    });
    Element.show(to);
    $('popular_ul_title').innerHTML = title;
    onMenu = 0;
    $('#bill_tab_select').hide().toggleClass('small_heading_hover');
}

$(document).ready(function(){

$('#popular_ul_title').hover(function(event) {
    $('#bill_tab_select').show().toggleClass('small_heading_hover');
}, function(event) {
    if (onMenu == 0) {
        $('#bill_tab_select').hide().toggleClass('small_heading_hover');
    }
});

$('#bill_tab_select').hover(function(event) {
    $('#bill_tab_select').show().toggleClass('small_heading_hover');
    onMenu = 1;
}, function(event) {
   if (onMenu == 1) {
       onMenu = 0;
       $('#bill_tab_select').hide().toggleClass('small_heading_hover');
   }
});

});
