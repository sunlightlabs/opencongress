/*!
 * Socialite v2.0
 * http://socialitejs.com
 * Copyright (c) 2011 David Bushell
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
window.Socialite = (function(window, document, undefined)
{
    'use strict';

    var uid       = 0,
        instances = [ ],
        networks  = { },
        widgets   = { },
        rstate    = /^($|loaded|complete)/,
        euc       = window.encodeURIComponent;

    var socialite = {

        settings: { },

        trim: function(str)
        {
            return str.trim ? str.trim() : str.replace(/^\s+|\s+$/g,'');
        },

        hasClass: function(el, cn)
        {
            return (' ' + el.className + ' ').indexOf(' ' + cn + ' ') !== -1;
        },

        addClass: function(el, cn)
        {
            if (!socialite.hasClass(el, cn)) {
                el.className = (el.className === '') ? cn : el.className + ' ' + cn;
            }
        },

        removeClass: function(el, cn)
        {
            el.className = socialite.trim(' ' + el.className + ' '.replace(' ' + cn + ' ', ' '));
        },

        /**
         * Copy properties of one object to another
         */
        extendObject: function(to, from, overwrite)
        {
            for (var prop in from) {
                var hasProp = to[prop] !== undefined;
                if (hasProp && typeof from[prop] === 'object') {
                    socialite.extendObject(to[prop], from[prop], overwrite);
                } else if (overwrite || !hasProp) {
                    to[prop] = from[prop];
                }
            }
        },

        /**
         * Return elements with a specific class
         *
         * @param context - containing element to search within
         * @param cn      - class name to search for
         *
         */
        getElements: function(context, cn)
        {
            // copy to a new array to avoid a live NodeList
            var i   = 0,
                el  = [ ],
                gcn = !!context.getElementsByClassName,
                all = gcn ? context.getElementsByClassName(cn) : context.getElementsByTagName('*');
            for (; i < all.length; i++) {
                if (gcn || socialite.hasClass(all[i], cn)) {
                    el.push(all[i]);
                }
            }
            return el;
        },

        /**
         * Return data-* attributes of element as a query string (or object)
         *
         * @param el       - the element
         * @param noprefix - (optional) if true, remove "data-" from attribute names
         * @param nostr    - (optional) if true, return attributes in an object
         *
         */
        getDataAttributes: function(el, noprefix, nostr)
        {
            var i    = 0,
                str  = '',
                obj  = { },
                attr = el.attributes;
            for (; i < attr.length; i++) {
                var key = attr[i].name,
                    val = attr[i].value;
                if (val.length && key.indexOf('data-') === 0) {
                    if (noprefix) {
                        key = key.substring(5);
                    }
                    if (nostr) {
                        obj[key] = val;
                    } else {
                        str += euc(key) + '=' + euc(val) + '&';
                    }
                }
            }
            return nostr ? obj : str;
        },

        /**
         * Copy data-* attributes from one element to another
         *
         * @param from     - element to copy from
         * @param to       - element to copy to
         * @param noprefix - (optional) if true, remove "data-" from attribute names
         * @param nohyphen - (optional) if true, convert hyphens to underscores in the attribute names
         *
         */
        copyDataAttributes: function(from, to, noprefix, nohyphen)
        {
            // `nohyphen` was needed for Facebook's <fb:like> elements - remove as no longer used?
            var attr = socialite.getDataAttributes(from, noprefix, true);
            for (var i in attr) {
                to.setAttribute(nohyphen ? i.replace(/-/g, '_') : i, attr[i]);
            }
        },

        /**
         * Create iframe element
         *
         * @param src      - iframe URL (src attribute)
         * @param instance - (optional) socialite instance to activate on iframe load
         *
         */
        createIframe: function(src, instance)
        {
            // Socialite v2 has slashed the amount of manual iframe creation, we should aim to avoid this entirely
            var iframe = document.createElement('iframe');
            iframe.style.cssText = 'overflow: hidden; border: none;';
            socialite.extendObject(iframe, { src: src, allowtransparency: 'true', frameborder: '0', scrolling: 'no' }, true);
            if (instance) {
                iframe.onload = iframe.onreadystatechange = function ()
                {
                    if (rstate.test(iframe.readyState || '')) {
                        iframe.onload = iframe.onreadystatechange = null;
                        socialite.activateInstance(instance);
                    }
                };
            }
            return iframe;
        },

        /**
         * Returns true if network script has loaded
         */
        networkReady: function(name)
        {
            return networks[name] ? networks[name].loaded : undefined;
        },

        /**
         * Append network script to the document
         */
        appendNetwork: function(network)
        {
            // the activation process is getting a little confusing for some networks
            // it would appear a script load event does not mean its global object exists yet
            // therefore the first call to `activateAll` may have no effect whereas the second call does, e.g. via `window.twttr.ready`

            if (!network || network.appended) {
                return;
            }
            // `network.append` and `network.onload` can cancel progress
            if (typeof network.append === 'function' && network.append(network) === false) {
                network.appended = network.loaded = true;
                socialite.activateAll(network);
                return;
            }

            if (network.script) {
                network.el = document.createElement('script');
                socialite.extendObject(network.el, network.script, true);
                network.el.async = true;
                network.el.onload = network.el.onreadystatechange = function()
                {
                    if (rstate.test(network.el.readyState || '')) {
                        network.el.onload = network.el.onreadystatechange = null;
                        network.loaded = true;
                        if (typeof network.onload === 'function' && network.onload(network) === false) {
                            return;
                        }
                        socialite.activateAll(network);
                    }
                };
                document.body.appendChild(network.el);
            }
            network.appended = true;
        },

        /**
         * Remove network script from the document
         */
        removeNetwork: function(network)
        {
            if (!socialite.networkReady(network.name)) {
                return false;
            }
            if (network.el.parentNode) {
                network.el.parentNode.removeChild(network.el);
            }
            return !(network.appended = network.loaded = false);
        },

        /**
         * Remove and re-append network script to the document
         */
        reloadNetwork: function(name)
        {
            // This is a last-ditch effort for half-baked scripts
            var network = networks[name];
            if (network && socialite.removeNetwork(network)) {
                socialite.appendNetwork(network);
            }
        },

        /**
         * Create new Socialite instance
         *
         * @param el     - parent element that will hold the new instance
         * @param widget - widget the instance belongs to
         *
         */
        createInstance: function(el, widget)
        {
            var proceed  = true,
                instance = {
                    el      : el,
                    uid     : uid++,
                    widget  : widget
                };
            instances.push(instance);
            if (widget.process !== undefined) {
                proceed = (typeof widget.process === 'function') ? widget.process(instance) : false;
            }
            if (proceed) {
                socialite.processInstance(instance);
            }
            instance.el.setAttribute('data-socialite', instance.uid);
            instance.el.className = 'socialite ' + widget.name + ' socialite-instance';
            return instance;
        },

        /**
         * Process a socialite instance to an intermediate state prior to load
         */
        processInstance: function(instance)
        {
            var el = instance.el;
            instance.el = document.createElement('div');
            instance.el.className = el.className;
            socialite.copyDataAttributes(el, instance.el);
            // stop over-zealous scripts from activating all instances
            if (el.nodeName.toLowerCase() === 'a' && !el.getAttribute('data-default-href')) {
                instance.el.setAttribute('data-default-href', el.getAttribute('href'));
            }
            var parent = el.parentNode;
            parent.insertBefore(instance.el, el);
            parent.removeChild(el);
        },

        /**
         * Activate a socialite instance
         */
        activateInstance: function(instance)
        {
            if (instance && !instance.loaded) {
                instance.loaded = true;
                if (typeof instance.widget.activate === 'function') {
                    instance.widget.activate(instance);
                }
                socialite.addClass(instance.el, 'socialite-loaded');
                return instance.onload ? instance.onload(instance.el) : null;
            }
        },

        /**
         * Activate all socialite instances belonging to a network
         */
        activateAll: function(network)
        {
            if (typeof network === 'string') {
                network = networks[network];
            }
            for (var i = 0; i < instances.length; i++) {
                var instance = instances[i];
                if (instance.init && instance.widget.network === network) {
                    socialite.activateInstance(instance);
                }
            }
        },

        /**
         * Load socialite instances
         *
         * @param context - (optional) containing element to search within
         * @param el      - (optional) individual or an array of elements to load
         * @param w       - (optional) widget name
         * @param onload  - (optional) function to call after each socialite instance has loaded
         * @param process - (optional) process but don't load network (if true)
         *
         */
        load: function(context, el, w, onload, process)
        {
            // use document as context if unspecified
            context = (context && typeof context === 'object' && context.nodeType === 1) ? context : document;

            // if no elements search within the context and recurse
            if (!el || typeof el !== 'object') {
                socialite.load(context, socialite.getElements(context, 'socialite'), w, onload, process);
                return;
            }

            var i;

            // if array of elements load each one individually
            if (/Array/.test(Object.prototype.toString.call(el))) {
                for (i = 0; i < el.length; i++) {
                    socialite.load(context, el[i], w, onload, process);
                }
                return;
            }

            // nothing was found...
            if (el.nodeType !== 1) {
                return;
            }

            // if widget name not specified search within the element classes
            if (!w || !widgets[w]) {
                w = null;
                var classes = el.className.split(' ');
                for (i = 0; i < classes.length; i++) {
                    if (widgets[classes[i]]) {
                        w = classes[i];
                        break;
                    }
                }
                if (!w) {
                    return;
                }
            }

            // find or create the Socialite instance
            var instance,
                widget = widgets[w],
                sid    = parseInt(el.getAttribute('data-socialite'), 10);
            if (!isNaN(sid)) {
                for (i = 0; i < instances.length; i++) {
                    if (instances[i].uid === sid) {
                        instance = instances[i];
                        break;
                    }
                }
            } else {
                instance = socialite.createInstance(el, widget);
            }

            // return if just processing (or no instance found)
            if (process || !instance) {
                return;
            }

            // initialise the instance
            if (!instance.init) {
                instance.init = true;
                instance.onload = (typeof onload === 'function') ? onload : null;
                widget.init(instance);
            }

            // append the parent network (all instances will be activated onload)
            // or activate immediately if network has already loaded
            if (!widget.network.appended) {
                socialite.appendNetwork(widget.network);
            } else {
                if (socialite.networkReady(widget.network.name)) {
                    socialite.activateInstance(instance);
                }
            }
        },

        /**
         * Load a single element
         *
         * @param el     - an individual element
         * @param w      - (optional) widget for this socialite instance
         * @param onload - (optional) function to call once each instance has loaded
         *
         */
        activate: function(el, w, onload)
        {
            // skip the first few steps
            window.Socialite.load(null, el, w, onload);
        },

        /**
         * Process elements to an intermediate state prior to load
         *
         * @param context - containing element to search within
         * @param el      - (optional) individual or an array of elements to load
         * @param w       - (optional) widget name
         *
         */
        process: function(context, el, w)
        {
            // stop before widget initialises instance
            window.Socialite.load(context, el, w, null, true);
        },

        /**
         * Add a new social network
         *
         * @param name   - unique name for network
         * @param params - additional data and callbacks
         *
         */
        network: function(n, params)
        {
            networks[n] = {
                name     : n,
                el       : null,
                appended : false,
                loaded   : false,
                widgets  : { }
            };
            if (params) {
                socialite.extendObject(networks[n], params);
            }
        },

        /**
         * Add a new social widget
         *
         * @param name   - name of owner network
         * @param w      - unique name for widget
         * @param params - additional data and callbacks
         *
         */
        widget: function(n, w, params)
        {
            params.name = n + '-' + w;
            if (!networks[n] || widgets[params.name]) {
                return;
            }
            params.network = networks[n];
            networks[n].widgets[w] = widgets[params.name] = params;
        },

        /**
         * Change the default Socialite settings for each network
         */
        setup: function(params)
        {
            socialite.extendObject(socialite.settings, params, true);
        }

    };

    return socialite;

})(window, window.document);

/**
 * Socialite Extensions - Pick 'n' Mix!
 */
(function(window, document, Socialite, undefined)
{

    // default to the Queen's English
    Socialite.setup({
        facebook: {
            lang: 'en_GB',
            appId: null
        },
        twitter: {
            lang: 'en'
        },
        googleplus: {
            lang: 'en-GB'
        }
    });


    // Facebook
    // http://developers.facebook.com/docs/reference/plugins/like/
    // http://developers.facebook.com/docs/reference/javascript/FB.init/

    Socialite.network('facebook', {
        script: {
            src : '//connect.facebook.net/{{language}}/all.js',
            id  : 'facebook-jssdk'
        },
        append: function(network)
        {
            var fb       = document.createElement('div'),
                settings = Socialite.settings.facebook,
                events   = { onlike: 'edge.create', onunlike: 'edge.remove', onsend: 'message.send' };

            fb.id = 'fb-root';
            document.getElementById('fb-root') || document.body.appendChild(fb);
            network.script.src = network.script.src.replace('{{language}}', settings.lang);
            if(typeof window.fbAsyncInit == 'function') window.oldFbAsyncInit = window.fbAsyncInit;
            window.fbAsyncInit = function() {
                if(typeof window.oldFbAsyncInit === 'function'){
                    oldFbAsyncInit();
                    window.oldFbAsyncInit = null;
                }else{
                    window.FB.init({
                        appId: settings.appId,
                        xfbml: true
                    });
                }
                for (var e in events) {
                    if (typeof settings[e] === 'function') {
                        window.FB.Event.subscribe(events[e], settings[e]);
                    }
                }
            };
            // this prevents socialite from appending the script tag.
            return false;
        }
    });

    Socialite.widget('facebook', 'like', {
        init: function(instance)
        {
            var el = document.createElement('div');
            el.className = 'fb-like';
            Socialite.copyDataAttributes(instance.el, el);
            instance.el.appendChild(el);
            if (window.FB && window.FB.XFBML) {
                window.FB.XFBML.parse(instance.el);
            }
        }
    });


    // // Twitter
    // // https://dev.twitter.com/docs/tweet-button/
    // // https://dev.twitter.com/docs/intents/events/
    // // https://developers.google.com/analytics/devguides/collection/gajs/gaTrackingSocial#twitter

    // Socialite.network('twitter', {
    //     script: {
    //         src     : '//platform.twitter.com/widgets.js',
    //         id      : 'twitter-wjs',
    //         charset : 'utf-8'
    //     },
    //     append: function()
    //     {
    //         var notwttr  = (typeof window.twttr !== 'object'),
    //             settings = Socialite.settings.twitter,
    //             events   = ['click', 'tweet', 'retweet', 'favorite', 'follow'];
    //         if (notwttr) {
    //             window.twttr = (t = { _e: [], ready: function(f) { t._e.push(f); } });
    //         }
    //         window.twttr.ready(function(twttr)
    //         {
    //             for (var i = 0; i < events.length; i++) {
    //                 var e = events[i];
    //                 if (typeof settings['on' + e] === 'function') {
    //                     twttr.events.bind(e, settings['on' + e]);
    //                 }
    //             }
    //             Socialite.activateAll('twitter');
    //         });
    //         return notwttr;
    //     }
    // });

    // var twitterInit = function(instance)
    // {
    //     var el = document.createElement('a');
    //     el.className = instance.widget.name + '-button';
    //     Socialite.copyDataAttributes(instance.el, el);
    //     el.setAttribute('href', instance.el.getAttribute('data-default-href'));
    //     el.setAttribute('data-lang', instance.el.getAttribute('data-lang') || Socialite.settings.twitter.lang);
    //     instance.el.appendChild(el);
    // };

    // var twitterActivate = function(instance)
    // {
    //     if (window.twttr && typeof window.twttr.widgets === 'object' && typeof window.twttr.widgets.load === 'function') {
    //         window.twttr.widgets.load();
    //     }
    // };

    // Socialite.widget('twitter', 'share',   { init: twitterInit, activate: twitterActivate });
    // Socialite.widget('twitter', 'follow',  { init: twitterInit, activate: twitterActivate });
    // Socialite.widget('twitter', 'hashtag', { init: twitterInit, activate: twitterActivate });
    // Socialite.widget('twitter', 'mention', { init: twitterInit, activate: twitterActivate });

    // Socialite.widget('twitter', 'embed', {
    //     process: function(instance)
    //     {
    //         instance.innerEl = instance.el;
    //         if (!instance.innerEl.getAttribute('data-lang')) {
    //             instance.innerEl.setAttribute('data-lang', Socialite.settings.twitter.lang);
    //         }
    //         instance.el = document.createElement('div');
    //         instance.el.className = instance.innerEl.className;
    //         instance.innerEl.className = '';
    //         instance.innerEl.parentNode.insertBefore(instance.el, instance.innerEl);
    //         instance.el.appendChild(instance.innerEl);
    //     },
    //     init: function(instance)
    //     {
    //         instance.innerEl.className = 'twitter-tweet';
    //     },
    //     activate: twitterActivate
    // });


    // Google+
    // https://developers.google.com/+/plugins/+1button/
    // Google does not support IE7

    Socialite.network('googleplus', {
        script: {
            src: '//apis.google.com/js/plusone.js'
        },
        append: function(network)
        {
            if (window.gapi) {
                return false;
            }
            window.___gcfg = {
                lang: Socialite.settings.googleplus.lang,
                parsetags: 'explicit'
            };
        }
    });

    var googleplusInit = function(instance)
    {
        var el = document.createElement('div');
        el.className = 'g-' + instance.widget.gtype;
        Socialite.copyDataAttributes(instance.el, el);
        instance.el.appendChild(el);
        instance.gplusEl = el;
    };

    var googleplusEvent = function(instance, callback) {
        return (typeof callback !== 'function') ? null : function(data) {
            callback(instance.el, data);
        };
    };

    var googleplusActivate = function(instance)
    {
        var type = instance.widget.gtype;
        if (window.gapi && window.gapi[type]) {
            var settings = Socialite.settings.googleplus,
                params   = Socialite.getDataAttributes(instance.el, true, true),
                events   = ['onstartinteraction', 'onendinteraction', 'callback'];
            for (var i = 0; i < events.length; i++) {
                params[events[i]] = googleplusEvent(instance, settings[events[i]]);
            }
            window.gapi[type].render(instance.gplusEl, params);
        }
    };

    Socialite.widget('googleplus', 'one',   { init: googleplusInit, activate: googleplusActivate, gtype: 'plusone' });
    Socialite.widget('googleplus', 'share', { init: googleplusInit, activate: googleplusActivate, gtype: 'plus' });
    Socialite.widget('googleplus', 'badge', { init: googleplusInit, activate: googleplusActivate, gtype: 'plus' });


    // LinkedIn
    // http://developer.linkedin.com/plugins/share-button/

    Socialite.network('linkedin', {
        script: {
            src: '//platform.linkedin.com/in.js'
        }
    });

    var linkedinInit = function(instance)
    {
        var el = document.createElement('script');
        el.type = 'IN/' + instance.widget.intype;
        Socialite.copyDataAttributes(instance.el, el);
        instance.el.appendChild(el);
        if (typeof window.IN === 'object' && typeof window.IN.parse === 'function') {
            window.IN.parse(instance.el);
            Socialite.activateInstance(instance);
        }
    };

    Socialite.widget('linkedin', 'share',     { init: linkedinInit, intype: 'Share' });
    Socialite.widget('linkedin', 'recommend', { init: linkedinInit, intype: 'RecommendProduct' });

})(window, window.document, window.Socialite);

/**
 * Execute any queued functions (don't enqueue before the document has loaded!)
 */
(function() {
    var s = window._socialite;
    if (/Array/.test(Object.prototype.toString.call(s))) {
        for (var i = 0, len = s.length; i < len; i++) {
            if (typeof s[i] === 'function') {
                s[i]();
            }
        }
    }
})();

/*!
 * Socialite v2.0 - Basic Email Share Extension
 * Copyright (c) 2013 Dan Drinkard
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{

    /**
     * This script generates a basic mailto: link with an empty address.
     * params are:
     *
     * url         | data-url         | URL to share
     * title       | data-title       | Subject line
     * description | data-description | Body text
     *
     */

    Socialite.network('email');

    function safeGetSelection() {
        if (window.getSelection) return window.getSelection();
        if (document.getSelection) return document.getSelection();
        if (document.selection) return document.selection.createRange().text;
        return '';
    }

    Socialite.widget('email', 'simple', {
        init: function(instance) {
            var el = document.createElement('a'),
                href = "mailto:?",
                attrs = Socialite.getDataAttributes(instance.el, true, true),
                title = encodeURIComponent(attrs['title']),
                description = encodeURIComponent(attrs['description']),
                selection = encodeURIComponent(safeGetSelection()),
                url = encodeURIComponent(attrs.url);

            el.className = instance.widget.name;
            Socialite.copyDataAttributes(instance.el, el);
            if(title) {
                href += '&subject=' + title;
                href += '&body=';
            }
            if(selection) href += selection;
            else if(description) href += description;
            if(url) href += '%0A%0A' + url;
            el.setAttribute('href', href);
            if (instance.el.getAttribute('data-image')) {
                imgTag = document.createElement('img');
                imgTag.src = instance.el.getAttribute('data-image');
                el.appendChild(imgTag);
            }
            instance.el.appendChild(el);
        },
        activate: function(){}
    });

})(window, window.document, window.Socialite);


/*!
 * Socialite v2.0 - Plain FB Share Extension
 * Copyright (c) 2013 Dan Drinkard
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{

    /**
     * FB Share is no longer supported, but params are:
     * u | data-url    | URL to share
     * t | data-title  | Title to share
     *
     * Others may work, but that will come later. For now just set OG tags.
     *
     */

    function addEvent(obj, evt, fn, capture) {
        if (window.attachEvent) {
            obj.attachEvent("on" + evt, fn);
        }
        else {
            if (!capture) capture = false; // capture
            obj.addEventListener(evt, fn, capture);
        }
    }

    Socialite.widget('facebook', 'share', {
        init: function(instance) {
            var el = document.createElement('a'),
                href = "//www.facebook.com/share.php?",
                attrs = Socialite.getDataAttributes(instance.el, true, true);

            el.className = instance.widget.name;
            Socialite.copyDataAttributes(instance.el, el);
            if(attrs.url) href += 'u=' + encodeURIComponent(attrs.url);
            if(attrs['title']) href += '&t=' + encodeURIComponent(attrs['title']);
            href += '&' + Socialite.getDataAttributes(el, true);
            el.setAttribute('href', href);
            el.setAttribute('data-lang', instance.el.getAttribute('data-lang') || Socialite.settings.facebook.lang);
            if (instance.el.getAttribute('data-image')) {
                imgTag = document.createElement('img');
                imgTag.src = instance.el.getAttribute('data-image');
                el.appendChild(imgTag);
            }
            addEvent(el, 'click', function(e){
                var t = e? e.target : window.event.srcElement;
                e.preventDefault();
                window.open(el.getAttribute('href'), 'fb-share', 'left=' + (screen.availWidth/2 - 350) + ',top=' + (screen.availHeight/2 - 163) + ',height=325,width=700,menubar=0,resizable=0,status=0,titlebar=0');
            });
            instance.el.appendChild(el);
        },
        activate: function(){}
    });

})(window, window.document, window.Socialite);


/*!
 * Socialite v2.0 - GitHub extension
 * http://socialitejs.com
 * Copyright (c) 2011 David Bushell
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{
    // http://markdotto.github.com/github-buttons/
    // https://github.com/markdotto/github-buttons/

    Socialite.network('github');

    // github.size[size][type][has_count][dimension]
    Socialite.setup({
        github: {
            size: [
                {
                    watch  : [ [ 62,20], [110,20] ],
                    fork   : [ [ 53,20], [ 95,20] ],
                    follow : [ [150,20], [200,20] ]
                },
                {
                    watch  : [ [100,30], [170,30] ],
                    fork   : [ [80, 30], [155,30] ],
                    follow : [ [200,30], [300,30] ]
                }
            ]
        }
    });

    var initGitHub = function(instance)
    {
        var type   = instance.el.getAttribute('data-type'),
            size   = instance.el.getAttribute('data-size') === 'large' ? 1 : 0,
            count  = instance.el.getAttribute('data-count') === 'true' ? 1 : 0,
            data   = Socialite.settings.github.size;

        type = (type && data[size].hasOwnProperty(type)) ? type : 'watch';

        instance.el.setAttribute('data-type', type);
        instance.el.setAttribute('data-count', !!count);

        Socialite.processInstance(instance);
        var src    = 'http://ghbtns.com/github-btn.html?' + Socialite.getDataAttributes(instance.el, true);
        var iframe = Socialite.createIframe(src, instance);
        iframe.style.width = data[size][type][count][0] + 'px';
        iframe.style.height = data[size][type][count][1] + 'px';
        instance.el.appendChild(iframe);
        Socialite.activateInstance(instance);
    };

    Socialite.widget('github', 'watch',  { process: null, init: initGitHub });
    Socialite.widget('github', 'fork',   { process: null, init: initGitHub });
    Socialite.widget('github', 'follow', { process: null, init: initGitHub });

})(window, window.document, window.Socialite);

/*!
 * Socialite v2.0 - Plain Google + Share Extension
 * Copyright (c) 2013 Dan Drinkard
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{

    /**
     * Google plus doesn't offer a share widget that is icon only, like their badge
     * The only param is url.
     *
     * url | data-url    | URL to share
     *
     * Inherits content from document meta information
     *
     */

    function addEvent(obj, evt, fn, capture) {
        if (window.attachEvent) {
            obj.attachEvent("on" + evt, fn);
        }
        else {
            if (!capture) capture = false; // capture
            obj.addEventListener(evt, fn, capture);
        }
    }

    Socialite.widget('googleplus', 'simple', {
        init: function(instance) {
            var el = document.createElement('a'),
                href = "//plus.google.com/share?",
                attrs = Socialite.getDataAttributes(instance.el, true, true);

            el.className = instance.widget.name;
            Socialite.copyDataAttributes(instance.el, el);
            href += '&' + Socialite.getDataAttributes(el, true);
            el.setAttribute('href', href);
            el.setAttribute('data-lang', instance.el.getAttribute('data-lang') || Socialite.settings.googleplus.lang);
            if (instance.el.getAttribute('data-image')) {
                imgTag = document.createElement('img');
                imgTag.src = instance.el.getAttribute('data-image');
                el.appendChild(imgTag);
            }
            addEvent(el, 'click', function(e){
                var t = e? e.target : window.event.srcElement;
                e.preventDefault();
                window.open(el.getAttribute('href'), 'gplus-share', 'left=' + (screen.availWidth/2 - 350) + ',top=' + (screen.availHeight/2 - 163) + ',height=300,width=600,menubar=0,resizable=0,status=0,titlebar=0');
            });
            instance.el.appendChild(el);
        },
        activate: function(){}
    });

})(window, window.document, window.Socialite);


//
// Hacker News
// https://github.com/igrigorik/hackernews-button
//
(function(window, document, Socialite, undefined)
{

    Socialite.network('hackernews', {
        script: {
            src: '//hnbutton.appspot.com/static/hn.js'
        }
    });

    var hackernewsInit = function(instance) {
        var el = document.createElement('a');
        el.className = 'hn-share-button';
        Socialite.copyDataAttributes(instance.el, el);
        instance.el.appendChild(el);
    };

    Socialite.widget('hackernews', 'share', {
        init: hackernewsInit,
        activate: function(instance) {
            if (window.HN) {
                window.HN.render(instance.el);
            }
        }
    });

})(window, window.document, window.Socialite);
/*!
 * Socialite v2.0 - Plain Linkedin Share Extension
 * Copyright (c) 2013 Dan Drinkard
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{

    /**
     * This is based on the linkedin bookmarklet: http://www.linkedin.com/static?key=browser_bookmarklet
     * Params are:
     *
     * url   | data-url    | URL to share
     * title | data-title  | Title to share
     *
     */

    function addEvent(obj, evt, fn, capture) {
        if (window.attachEvent) {
            obj.attachEvent("on" + evt, fn);
        }
        else {
            if (!capture) capture = false; // capture
            obj.addEventListener(evt, fn, capture);
        }
    }

    Socialite.widget('linkedin', 'simple', {
        init: function(instance) {
            var el = document.createElement('a'),
                href = "//www.linkedin.com/shareArticle?mini=true&ro=false&trk=socialite.linkedin-simple",
                attrs = Socialite.getDataAttributes(instance.el, true, true);

            el.className = instance.widget.name;
            Socialite.copyDataAttributes(instance.el, el);
            href += '&' + Socialite.getDataAttributes(el, true);
            el.setAttribute('href', href);
            if (instance.el.getAttribute('data-image')) {
                imgTag = document.createElement('img');
                imgTag.src = instance.el.getAttribute('data-image');
                el.appendChild(imgTag);
            }
            addEvent(el, 'click', function(e){
                var t = e? e.target : window.event.srcElement;
                e.preventDefault();
                window.open(el.getAttribute('href'), 'linkedin-simple', 'left=' + (screen.availWidth/2 - 300) + ',top=' + (screen.availHeight/2 - 200) + ',height=400,width=600,menubar=0,resizable=0,status=0,titlebar=0');
            });
            instance.el.appendChild(el);
        },
        activate: function(){}
    });

})(window, window.document, window.Socialite);


/*!
 * Socialite v2.0 - LinkedIn extension
 * http://socialitejs.com
 * Copyright (c) 2011 David Bushell
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{
    // http://developer.linkedin.com/plugins/share-button/

    Socialite.network('linkedin', {
        script: {
            src: '//platform.linkedin.com/in.js'
        }
    });

    var linkedinInit = function(instance)
    {
        var el = document.createElement('script');
        el.type = 'IN/' + instance.widget.intype;
        Socialite.copyDataAttributes(instance.el, el);
        instance.el.appendChild(el);
        if (typeof window.IN === 'object' && typeof window.IN.parse === 'function') {
            window.IN.parse(instance.el);
            Socialite.activateInstance(instance);
        }
    };

    Socialite.widget('linkedin', 'share',     { init: linkedinInit, intype: 'Share' });
    Socialite.widget('linkedin', 'recommend', { init: linkedinInit, intype: 'RecommendProduct' });

})(window, window.document, window.Socialite);

/*!
 * Socialite v2.0 - Pinterest extension
 * http://socialitejs.com
 * Copyright (c) 2011 David Bushell
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{
    // http://pinterest.com/about/goodies/

    Socialite.network('pinterest', {
        script: {
            src: '//assets.pinterest.com/js/pinit.js'
        }
    });

    Socialite.widget('pinterest', 'pinit', {
        process: function(instance)
        {
            // Pinterest activates all <a> elements with a href containing share URL
            // so we have to jump through hoops to protect each instance
            if (instance.el.nodeName.toLowerCase() !== 'a') {
                return true;
            }
            var id   = 'socialite-instance-' + instance.uid,
                href = instance.el.getAttribute('href');
            instance.el.id = id;
            instance.el.href = '#' + id;
            instance.el.setAttribute('data-default-href', href);
            instance.el.setAttribute('onclick', '(function(){window.open("' + href + '")})();');
        },
        init: function(instance)
        {
            Socialite.processInstance(instance);
            var el = document.createElement('a');
            el.className = 'pin-it-button';
            Socialite.copyDataAttributes(instance.el, el);
            el.setAttribute('href', instance.el.getAttribute('data-default-href'));
            el.setAttribute('count-layout', instance.el.getAttribute('data-count-layout') || 'horizontal');
            instance.el.appendChild(el);
            if (Socialite.networkReady('pinterest')) {
                Socialite.reloadNetwork('pinterest');
            }
        }
    });

})(window, window.document, window.Socialite);

/*!
 * Socialite v2.0 - Plain Tumblr Share Extension
 * Copyright (c) 2013 Dan Drinkard
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{

    /**
     * This script is based on the tumblr bookmarklet: http://www.tumblr.com/apps
     * params are:
     *
     * u | data-url    | URL to share
     * t | data-title  | Title to share
     *
     */

    Socialite.network('tumblr');

    function addEvent(obj, evt, fn, capture) {
        if (window.attachEvent) {
            obj.attachEvent("on" + evt, fn);
        }
        else {
            if (!capture) capture = false; // capture
            obj.addEventListener(evt, fn, capture);
        }
    }

    function safeGetSelection() {
        if (window.getSelection) return window.getSelection();
        if (document.getSelection) return document.getSelection();
        if (document.selection) return document.selection.createRange().text;
        return '';
    }

    Socialite.widget('tumblr', 'simple', {
        init: function(instance) {
            var el = document.createElement('a'),
                href = "//www.tumblr.com/share?v=3&",
                attrs = Socialite.getDataAttributes(instance.el, true, true),
                selection;

            el.className = instance.widget.name;
            Socialite.copyDataAttributes(instance.el, el);
            if(attrs.url) href += 'u=' + encodeURIComponent(attrs.url);
            if(attrs['title']) href += '&t=' + encodeURIComponent(attrs['title']);
            if(selection = safeGetSelection()) href += '&s=' + encodeURIComponent(selection);
            href += '&' + Socialite.getDataAttributes(el, true);
            el.setAttribute('href', href);
            if (instance.el.getAttribute('data-image')) {
                imgTag = document.createElement('img');
                imgTag.src = instance.el.getAttribute('data-image');
                el.appendChild(imgTag);
            }
            addEvent(el, 'click', function(e){
                var t = e? e.target : window.event.srcElement;
                e.preventDefault();
                window.open(el.getAttribute('href'), 'tumblr-simple', 'left=' + (screen.availWidth/2 - 225) + ',top=' + (screen.availHeight/2 - 215) + ',height=430,width=450,menubar=0,resizable=0,status=0,titlebar=0');
            });
            instance.el.appendChild(el);
        },
        activate: function(){}
    });

})(window, window.document, window.Socialite);


/*!
 * Socialite v2.0 - Plain Twitter Extension
 * Copyright (c) 2013 Dan Drinkard
 * Dual-licensed under the BSD or MIT licenses: http://socialitejs.com/license.txt
 */
(function(window, document, Socialite, undefined)
{
    // https://dev.twitter.com/docs/intents/events/

    var twitterActivate = function(instance)
    {
        if (window.twttr && typeof window.twttr.widgets === 'object' && typeof window.twttr.widgets.load === 'function') {
            window.twttr.widgets.load();
        }
    };

    Socialite.widget('twitter', 'simple',   { init: function(instance){
        var el = document.createElement('a'),
            href = "//twitter.com/intent/tweet?";
        el.className = instance.widget.name;
        Socialite.copyDataAttributes(instance.el, el);
        href += Socialite.getDataAttributes(el, true);
        el.setAttribute('href', href);
        el.setAttribute('data-lang', instance.el.getAttribute('data-lang') || Socialite.settings.twitter.lang);
        if (instance.el.getAttribute('data-image')) {
            imgTag = document.createElement('img');
            imgTag.src = instance.el.getAttribute('data-image');
            el.appendChild(imgTag);
        }
        instance.el.appendChild(el);
    }, activate: twitterActivate });

})(window, window.document, window.Socialite);


// Generated by CoffeeScript 1.3.3

/*
Simple-Socialite
----------------

A silently failing, HTML tag-based abstraction API for socialite.js

Usage:
<div class="share-buttons" data-socialite="auto" data-services="twitter, facebook"></div>
*/


/*
Global object for classes
*/


(function() {
  var check, tries, _ref,
    _this = this,
    __slice = [].slice;

  if ((_ref = window.SimpleSocialite) == null) {
    window.SimpleSocialite = {};
  }

  /*
  check() ensures all dependencies are loaded
  before defining any classes that reference them.
  */


  tries = 0;

  check = function() {
    var $, DEBUG, OptionMapper, ShareBar, ShareButton, debug, htmlEscaper, htmlEscapes, _base, _ref1;
    if (!(typeof jQuery !== "undefined" && jQuery !== null)) {
      if (tries < 6000) {
        tries++;
        return setTimeout(check, 10);
      } else {
        return (typeof console !== "undefined" && console !== null) && console.log('Gave up trying to render your social buttons. Make sure jQuery is getting on the page at some point.');
      }
    } else {
      $ = jQuery;
      DEBUG = ("false".toLowerCase() === "true") || false;
      debug = function() {
        var msgs;
        msgs = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return DEBUG && (typeof console !== "undefined" && console !== null) && console.log.apply(console, msgs);
      };
      /*
          Tiny plugin to return a nested object of all data-foo options on an element
      */

      $.fn.getDataOptions = function() {
        var el, opts,
          _this = this;
        opts = {};
        el = $(this)[0];
        $.each(el.attributes, function(i, att) {
          var key, qs;
          if (!att.nodeName.match(/^data-/)) {
            return true;
          }
          qs = att.nodeValue;
          key = att.nodeName.replace(/^data-/, '');
          if (key.match(/options$/)) {
            return opts[key] = $.optionsFromQueryString(qs);
          } else {
            return opts[key] = qs;
          }
        });
        return opts;
      };
      $.optionsFromQueryString = function(qs) {
        var opts, parts,
          _this = this;
        opts = {};
        parts = qs.split(/(?:&(?:amp;)?|=)/);
        $.each(parts, function(i, part) {
          if (i % 2) {
            return opts[parts[i - 1]] = decodeURIComponent(part);
          }
        });
        debug(opts);
        return opts;
      };
      htmlEscapes = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#x27;',
        '/': '&#x2F;'
      };
      htmlEscaper = /[&<>"'\/]/g;
      $.safeString = function(s) {
        return ('' + s).replace(htmlEscaper, function(match) {
          return htmlEscapes[match];
        });
      };
      /*
          Individual share button class
          Takes a string @provider and object @options
      */

      ShareButton = (function() {
        var _ref1;

        if ((_ref1 = ShareButton._customNames) == null) {
          ShareButton._customNames = {
            "twitter-share": "Twitter",
            "facebook-like": "Facebook",
            "pinterest-pinit": "Pinterest",
            "googleplus-one": "Google Plus"
          };
        }

        ShareButton.customNames = function() {
          return this._customNames;
        };

        ShareButton.registerCustomName = function(name, displayName) {
          if (this.customNames()[name] != null) {
            throw "Custom name " + name + " is already registered.";
          }
          return this._customNames[name] = displayName;
        };

        function ShareButton(provider, options) {
          this.provider = provider;
          this.options = options;
        }

        ShareButton.prototype.to_html_params = function() {
          var opts,
            _this = this;
          opts = '';
          this.options = new OptionMapper(this.provider, this.options).translate();
          $.each(this.options, function(key, val) {
            var escaped_val;
            escaped_val = $.safeString(val);
            return opts += "data-" + key + "=\"" + escaped_val + "\" ";
          });
          return opts.replace(/\ $/, '');
        };

        ShareButton.prototype.provider_display = function() {
          var _this = this;
          return this.constructor.customNames()[this.provider] || (function() {
            var name, parts;
            name = _this.provider.replace(/-simple$/, '');
            parts = name.split(' ');
            $.each(parts, function(i, part) {
              return parts[i] = part.charAt(0).toUpperCase() + part.slice(1);
            });
            return parts.join(' ');
          })();
        };

        ShareButton.prototype.render = function() {
          return "<a href='' class='socialite " + this.provider + "' " + (this.to_html_params()) + ">Share on " + (this.provider_display()) + "</a>";
        };

        return ShareButton;

      })();
      window.SimpleSocialite.ShareButton = ShareButton;
      /*
          Share bar class
          Takes a DOM or jQuery element @wrapper, such as:
          new ShareBar $('<div class="share-buttons" data-socialite="auto" data-services="facebook,twitter"></div>')
      */

      ShareBar = (function() {

        ShareBar._container = $("<table style='vertical-align:middle;'><tbody></tbody></table>");

        ShareBar._defaults = {
          layout: 'horizontal',
          shortURLs: 'never',
          showTooltips: false
        };

        ShareBar._services = {
          "twitter-simple": {},
          "twitter-share": {},
          "twitter-follow": {},
          "twitter-mention": {},
          "twitter-hashtag": {},
          "twitter-embed": {},
          "facebook-like": {},
          "facebook-share": {},
          "googleplus-simple": {},
          "googleplus-one": {},
          "linkedin-share": {},
          "linkedin-simple": {},
          "linkedin-recommend": {},
          "pinterest-pinit": {},
          "spotify-play": {},
          "hackernews-share": {},
          "github-watch": {},
          "github-fork": {},
          "github-follow": {},
          "tumblr-simple": {},
          "email-simple": {}
        };

        ShareBar._serviceMappings = {
          "twitter": "twitter-simple",
          "twitter-tweet": "twitter-share",
          "facebook": "facebook-share",
          "googleplus": "googleplus-simple",
          "google-plusone": "googleplus-one",
          "linkedin": "linkedin-simple",
          "pinterest": "pinterest-pinit",
          "tumblr": "tumblr-simple",
          "email": "email-simple"
        };

        ShareBar.container = function() {
          return this._container.clone();
        };

        ShareBar.setContainer = function(str) {
          return this._container = $(str);
        };

        ShareBar.defaults = function() {
          return this._defaults;
        };

        ShareBar.setDefault = function(key, val) {
          var _ref1;
          if ((_ref1 = this._defaults) == null) {
            this._defaults = this.defaults();
          }
          this._defaults[key] = val;
          return this._defaults;
        };

        ShareBar.services = function() {
          return this._services;
        };

        ShareBar.serviceMappings = function() {
          return this._serviceMappings;
        };

        ShareBar.registerButton = function(opts) {
          var defaults, displayName, name, nickname;
          name = opts.name;
          nickname = opts.nickname;
          defaults = opts.defaults || {};
          if (opts.displayName != null) {
            displayName = opts.displayName;
          }
          if (!(opts.name != null)) {
            throw 'You must provide a name to register.';
          }
          if ((this.services()[name] != null) || (this.serviceMappings()[nickname] != null)) {
            throw "Name " + name + " is already registered.";
          }
          if (this.serviceMappings()[nickname] != null) {
            throw "Nickname " + nickname + " is already registered.";
          }
          this._services[name] = defaults;
          this._serviceMappings[nickname] = name;
          if (displayName != null) {
            return ShareButton.registerCustomName(name, displayName);
          }
        };

        function ShareBar(wrapper) {
          var _this = this;
          this.wrapper = wrapper;
          this.wrapper = $(this.wrapper);
          this.options = $.extend({}, this.constructor.defaults(), $(this.wrapper).getDataOptions());
          this.buttons = [];
          $.each(this.options.services.split(/, ?/), function(i, service) {
            var resolvedService;
            resolvedService = _this.constructor.serviceMappings()[service] || service;
            return _this.buttons.push(new ShareButton(resolvedService, $.extend({}, _this.constructor.services()[resolvedService], _this.options.options, _this.options["" + resolvedService + "-options"], _this.options["" + service + "-options"])));
          });
        }

        ShareBar.prototype.render = function() {
          var cursor,
            _this = this;
          this.rendered = this.constructor.container();
          cursor = this.rendered.find('tbody');
          if (this.options.layout === 'horizontal') {
            cursor = cursor.append('<tr></tr>').find('tr');
          }
          $.each(this.buttons, function(i, button) {
            var btn;
            btn = $("<td>" + (button.render()) + "</td>");
            if (_this.options.layout === 'vertical') {
              btn = btn.wrap('<tr></tr>').parents('tr');
            }
            return cursor.append(btn);
          });
          this.wrapper.empty().append(this.rendered);
          debug("loading contents of " + this.wrapper);
          return Socialite.load(this.wrapper[0]);
        };

        return ShareBar;

      })();
      if ((_ref1 = (_base = window.SimpleSocialite).ShareBar) == null) {
        _base.ShareBar = ShareBar;
      }
      /*
          Option mapper class
          Normalizes a set of options to a given service's specific params
      */

      OptionMapper = (function() {

        function OptionMapper(provider, options) {
          var _this = this;
          this.provider = provider;
          this.options = options;
          this.translations = {
            "twitter-share": function() {
              if (!_this.options['size']) {
                (_this.options['size'] = _this.options['width']) && delete _this.options['width'];
              }
              if (!_this.options['text']) {
                (_this.options['text'] = _this.options['defaultText']) && delete _this.options['defaultText'];
              }
              if (!_this.options['text']) {
                (_this.options['text'] = _this.options['title']) && delete _this.options['title'];
              }
              if (_this.options['lang']) {
                _this.options['lang'] = _this.options['lang'].replace(/-.+$/, '');
              }
              return _this.options;
            },
            "twitter-simple": function() {
              return _this.translations["twitter-share"]();
            },
            "facebook-like": function() {
              if (!_this.options['href']) {
                (_this.options['href'] = _this.options['url']) && delete _this.options['url'];
              }
              if (!_this.options['layout']) {
                if (_this.options['showCounts'] === 'right') {
                  _this.options['layout'] = 'button_count';
                }
              }
              if (_this.options['lang']) {
                _this.options['lang'] = _this.options['lang'].replace('-', '_');
              }
              return _this.options;
            },
            "googleplus-one": function() {
              var _ref2;
              if (!_this.options['showCounts'] && !_this.options['annotation']) {
                _this.options['annotation'] = 'none';
              }
              if (_this.options['showCounts'] && !_this.options['annotation']) {
                if ((_ref2 = _this.options['showCounts']) === 'right' || _ref2 === 'top') {
                  delete _this.options['annotation'];
                  if (_this.options['showCounts'] === 'top') {
                    _this.options['size'] = 'tall';
                  }
                }
              }
              if (_this.options['size'] === 24 || (_this.options['size'] === 16 && _this.options['showCounts'] === 'right')) {
                delete _this.options['size'];
              }
              if (_this.options['size'] === 16) {
                _this.options['size'] = 'small';
              }
              if (!_this.options['href']) {
                (_this.options['href'] = _this.options['url']) && delete _this.options['url'];
              }
              return _this.options;
            },
            "googleplus-share": function() {
              if (!_this.options['showCounts'] && !_this.options['annotation']) {
                _this.options['annotation'] = 'none';
              }
              if (!_this.options['annotation']) {
                if (_this.options['showCounts'] === 'right') {
                  _this.options['annotation'] = 'bubble';
                }
                if (_this.options['showCounts'] === 'top') {
                  _this.options['annotation'] = 'vertical-bubble';
                }
              }
              if (_this.options['size'] === 16) {
                delete _this.options['size'];
              }
              if (_this.options['size'] === 24) {
                _this.options['height'] = 24;
                delete _this.options['size'];
              }
              if (!_this.options['href']) {
                (_this.options['href'] = _this.options['url']) && delete _this.options['url'];
              }
              return _this.options;
            },
            "linkedin-share": function() {
              if (_this.options['showCounts'] && !_this.options['counter']) {
                return (_this.options['counter'] = _this.options['showCounts']) && delete _this.options['showCounts'];
              }
            }
          };
          window.optionMapper = this;
        }

        OptionMapper.prototype.provider_icon_name = function() {
          return {
            "facebook-share": "facebook",
            "googleplus-one": "googleplus"
          }[this.provider] || this.provider.replace(/-simple$/, '');
        };

        OptionMapper.prototype.button_img = function() {
          return "//s3.amazonaws.com/assets.sunlightfoundation.com/social/images/" + this.options['size'] + "/" + (this.provider_icon_name()) + ".png";
        };

        OptionMapper.prototype.translate = function() {
          var _ref2, _ref3;
          if (!(this.options['size'] != null)) {
            this.options['size'] = 16;
          }
          if (typeof this.options['size'] === 'string' && !isNaN(parseInt(this.options['size'], 10))) {
            this.options['size'] = parseInt(this.options['size'], 10);
          }
          if (typeof this.options['size'] === 'number') {
            this.options['size'] = (_ref2 = this.options.size) === 16 || _ref2 === 24 ? this.options.size : 16;
          }
          if (!this.options['url']) {
            if (this.options['linkBack'] != null) {
              (this.options['url'] = this.options['linkBack']) && delete this.options['linkBack'];
            }
          }
          if (!this.options['url']) {
            this.options['url'] = $('meta[property="og:url"]').attr('content') || location.href;
          }
          if (!this.options['title']) {
            this.options['title'] = $('meta[property="og:title"]').attr('content') || document.title;
          }
          if (!this.options['image']) {
            this.options['image'] = this.button_img();
          }
          if ((_ref3 = this.options['showCounts']) === 'none' || _ref3 === 'false' || _ref3 === 'never') {
            delete this.options['showCounts'];
          }
          if (!this.options['lang']) {
            this.options['lang'] = "en-US";
          }
          try {
            this.translations[this.provider]();
          } catch (e) {
            debug("Totally failed to resolve options: " + e + ". Falling back to defaults");
            this.options;
          }
          return this.options;
        };

        return OptionMapper;

      })();
      /*
          Main bootstrap on dom ready
      */

      return $(function() {
        var initFB, initShareBar, register, selector, trackBasic, trackTwitter;
        debug("running onready bootstrap");
        selector = '.share-buttons[data-socialite], .share-buttons[data-gigya]';
        initShareBar = function(el) {
          try {
            $(el).data('sharebar', new ShareBar(el));
            return $(el).data('sharebar');
          } catch (e) {
            return debug("Caught error initializing sharebar: " + e);
          }
        };
        register = function(el) {
          var trigger,
            _this = this;
          el = $(el);
          trigger = el.attr('data-gigya') || $(el).attr('data-socialite');
          try {
            el.on(trigger, function() {
              return initShareBar(el[0]).render();
            });
          } catch (e) {
            el.bind(trigger, function() {
              return initShareBar(el[0]).render();
            });
          }
          return el.trigger('auto');
        };
        try {
          $('body').on('register.simplesocialite', selector, function() {
            return register(this);
          });
        } catch (e) {
          $('body').delegate(selector, 'register.simplesocialite', function() {
            return register(this);
          });
        }
        $(selector).each(function() {
          return register(this);
        });
        /*
              Set up GA tracking for the basic social networks and for clicks
              that bubble through `.socialite-instance`s, if _gaq is present
        */

        if (window._gaq != null) {
          initFB = function() {
            FB.Event.subscribe('edge.create', function(url) {
              debug('tracking facebook');
              return _gaq.push(['_trackSocial', 'facebook', 'like', url]);
            });
            return FB.Event.subscribe('edge.remove', function(url) {
              return _gaq.push(['_trackSocial', 'facebook', 'unlike', url]);
            });
          };
          window._fbAsyncInit = window.fbAsyncInit;
          window.fbAsyncInit = function() {
            if (typeof window._fbAsyncInit === 'function') {
              window._fbAsyncInit();
            }
            return initFB();
          };
          if (window.FB != null) {
            initFB();
          }
          if (window.twttr != null) {
            trackTwitter = function(evt) {
              var path;
              debug('tracking twitter');
              try {
                path = evt && evt.target && evt.target.nodeName === 'IFRAME' ? $.optionsFromQueryString(evt.target.src.split('?')[1]).url : null;
              } catch (e) {
                path = null;
              }
              return _gaq.push(['_trackSocial', 'twitter', 'tweet', path || location.href]);
            };
            twttr.ready(function(twttr) {
              return twttr.events.bind('tweet', trackTwitter);
            });
          }
          trackBasic = function(evt) {
            var button, el;
            if ($(evt.target).hasClass('.socialite-instance')) {
              el = $(evt.target);
            } else {
              el = $(evt.target).parents('.socialite-instance').eq(0);
            }
            button = el.attr('class').split(' ')[1];
            if (button.match(/twitter/) && (window.twttr != null)) {
              return;
            }
            debug("tracking " + button);
            return _gaq.push(['_trackSocial', button, 'share', location.href]);
          };
          return (($().on != null) && $('body').on('click', '.socialite-instance', trackBasic)) || $('body').delegate('.socialite-instance', 'click', trackBasic);
        }
      });
    }
  };

  /*
  Kick off the jQuery check
  */


  check();

}).call(this);
