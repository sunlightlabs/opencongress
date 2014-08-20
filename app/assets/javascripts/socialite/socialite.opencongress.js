/*!
 * Socialite v2.0 - OpenCongress Share Extension
 * Copyright (c) 2013 Dan Drinkard
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{

    function addEvent(obj, evt, fn, capture) {
        if (window.attachEvent) {
            obj.attachEvent("on" + evt, fn);
        }
        else {
            if (!capture) capture = false; // capture
            obj.addEventListener(evt, fn, capture);
        }
    }

    Socialite.network('opencongress');

    /**
     * This script generates a popup link to send content via email on OpenCongress
     * params are:
     *
     * object_class | data-object-class | Model of the object to share
     * object_id    | data-object-id    | ID of the object to share
     * dev          | data-dev          | Boolean switch to pin url path to the site domain or not
     *
     */
    Socialite.widget('opencongress', 'email', {
        init: function(instance) {
            var el = document.createElement('a'),
                href = "/tools/email_friend_form_popup?",
                attrs = Socialite.getDataAttributes(instance.el, true, true),
                object_class = encodeURIComponent(attrs['object-class']),
                object_id = encodeURIComponent(attrs['object-id']),
                dev = attrs['dev'];

            if(!dev) href = 'http://opencongress.org' + href;

            el.className = instance.widget.name;
            Socialite.copyDataAttributes(instance.el, el);
            if(object_id && object_class) {
                href += '&object_class=' + object_class;
                href += '&object_id=' + object_id;
            }
            el.setAttribute('href', href);
            if (instance.el.getAttribute('data-image')) {
                imgTag = document.createElement('img');
                imgTag.src = instance.el.getAttribute('data-image');
                el.appendChild(imgTag);
            }
            addEvent(el, 'click', function(e){
                var t = e? e.target: window.event.srcElement;
                e.preventDefault();
                window.open(
                    el.getAttribute('href'),
                    'opencongress-email',
                    'left=' + (screen.availWidth/2 - 225) + ',top=' + (screen.availHeight/2 - 200) + ',height=400,width=450,menubar=0,resizable=0,status=0,titlebar=0'
                );
            });
            instance.el.appendChild(el);
        },
        activate: function(){}
    });

})(window, window.document, window.Socialite);
