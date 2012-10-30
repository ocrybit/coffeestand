!function ($) {
    $(function(){

	var $window = $(window)

	// side bar
	$('.gh-pages-sidenav').affix({
	    offset: {
		top: function () { return $window.width() <= 980 ? 490 : 410 }
		, bottom: 270
	    }
	});
	window.prettyPrint && prettyPrint();
    })


}(window.jQuery)