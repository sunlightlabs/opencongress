(function($){
    $(document).ready(function() {

        $('#sfapp-subscribe-form').submit(function(ev) {

            var $form = $(this);

            var response_type = $form.find('input[name=response]').val(),
                email = $form.find('input[name=email]').val(),
                zipcode = $form.find('input[name=zipcode]').val(),
                url = $form.attr('action') || '/subscribe/';

            var data = {
                response: response_type,
                email: email,
                zipcode: zipcode
            };

            var params = {
              type: 'POST',
              url: url,
              data: data
            };

            // Add preflight request if the url is on a different domain
            if(url.match(/^http/) && !url.match(new RegExp('^https?:\/\/' + location.host.replace('.', '\\.')))){
              params['headers'] = {
                'Access-Control-Allow-Headers': 'x-requested-with, x-requested-by'
              };
            }

            $.ajax(params).success(function(resp) {
                var $p = $('<p>').text(resp.message).hide();
                $form.slideUp('fast', function() {
                    $form.after($p);
                    $p.slideDown();
                });
            });

            ev.preventDefault();

        });

    });
})(jQuery)