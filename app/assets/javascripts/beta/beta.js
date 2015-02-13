$(document).ready(function() {
    var wrap = $('.js-wrap'),
        navicon = $('.navicon');

    function resetNav(e) {
      if (!$(e.target).closest('.navigation--flyout').length) {
        closeNav();
        $(document).off('click', resetNav);
      }
    }

    function closeNav() {
      wrap.removeClass('is-active');
      navicon.removeClass('is-active');
    }

    $('.js-nav-toggle').click(function (e) {
      e.stopPropagation();
      navicon.toggleClass('is-active');
      wrap.toggleClass('is-active');
      $(document).on('click', resetNav);
    });
});