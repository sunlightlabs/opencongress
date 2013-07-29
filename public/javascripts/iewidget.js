(function($){

    function toTitleCase(str)
    {
        return str.replace(/\b\w+/g, function(txt){return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});
    }

    function Options (defaults, options) {
        if (this === undefined) { return new Options(defaults, options); }
        var that = this;

        if (defaults == null) { throw 'Options requires 1 or 2 parameters'; }
        // Demote Options back to their input Objects
        defaults = (defaults.options === undefined) ? defaults : defaults.options();
        options = (options == null) ? {} : options;
        options = (options.options === undefined) ? options : options.options();

        // Combined options
        options = $.extend(true, {}, defaults, options);

        that.get = function (k) {
            return options[k];
        };

        that.require = function (k) {
            if (options[k] == null) {
                throw "" + k.toString() + " is required.";
            }
        };

        that.options = function () { return options; };

        return this;
    };

    IE = function (defaults) {
        if (this === undefined) { return new IE(defaults); }
        var that = this;

        defaults = new Options(defaults);
        defaults.require('apikey');

        var Lookup = function (ns, id) {
            var url = 'http://transparencydata.com/api/1.0/entities/id_lookup.json';
            var params = { 'apikey': defaults.get('apikey'), 'namespace': ns, 'id': id };
            var def = $.Deferred();

            $.ajax({url: url,
                    crossDomain: true,
                    data: params,
                    dataType: 'jsonp'}).done(function(results){
                        return def.resolveWith(null, [results[0].id]);
                    });
            return def.promise();
        };

        var EntityOverview = function (infex_id) {
            var url = 'http://transparencydata.com/api/1.0/entities/:id.json'.replace(':id', infex_id);
            var params = { 'apikey': defaults.get('apikey') };
            var def = $.Deferred();

            $.ajax({url: url,
                    crossDomain: true,
                    data: params,
                    dataType: 'jsonp'}).done(function(result){
                        return def.resolveWith(null, [result]);
                    });
            return def.promise();
        };

        var FetchTopIndustries = function (infex_id, options) {
            options = new Options(defaults, options);
            options.require('cycle');
            var url = 'http://transparencydata.com/api/1.0/aggregates/pol/:id:/contributors/industries.json'.replace(':id:', infex_id);
            var params = { 'apikey': options.get('apikey'), 'cycle': options.get('cycle') };
            return $.ajax({url: url, crossDomain: true, data: params, dataType: 'jsonp'});
        };

        var IndustriesWidget = function (options) {
            options = new Options(defaults, options);
            options.require('recipient');
            options.require('cycle');

            var _FetchTopIndustries = function (infex_id) {
                return FetchTopIndustries(infex_id, options);
            };

            var display_top_industries = function (industries) {
                industries.sort(function(a,b) { return parseFloat(b.amount) - parseFloat(a.amount); });

                $.build(function(b){
                    b.ol({id: 'industries'},
                         b.li({'class': 'industry'},
                             b.span({'class': 'industry-name'}, 'Industry'),
                             b.span({'class': 'industry-contrib'}, 'Total')),
                         industries,
                         function(idx, ind){
                             b.li({'class': 'industry'},
                                 b.span({'class': 'industry-name'}, toTitleCase(ind.name)),
                                 b.span({'class': 'industry-contrib money'}, ind.amount));
                         }
                    );
                }).appendTo(options.get('target'));

                $(options.get('target')).find('span.money').formatCurrency({roundToDecimalPlace: 0});
            };

            _FetchTopIndustries(options.get('recipient'))
            .done(display_top_industries); 
        };

        var FetchTopContributors = function (infex_id, options) {
            options = new Options(defaults, options);
            options.require('cycle');
            var url = 'http://transparencydata.com/api/1.0/aggregates/pol/f990d08287c34c389cfabe3cbf3dde99/contributors.json';
            var params = { 'apikey': options.get('apikey'), 'cycle': options.get('cycle') };
            return $.ajax({url: url, crossDomain: true, data: params, dataType: 'jsonp'});
        };

        var ContributorsWidget = function (options) {
            options = new Options(defaults, options);
            options.require('recipient');
            options.require('cycle');

            var _FetchTopContributors = function (infex_id) {
                return FetchTopContributors(infex_id, options);
            };

            var display_top_contributors = function (contributors) {
                contributors.sort(function(a,b) { return parseFloat(b.total_amount) - parseFloat(a.total_amount); });

                $.build(function(b){
                    b.ol({id: 'contributors'},
                         b.li({'class': 'contributor'},
                             b.span({'class': 'contributor-name'}, 'Contributor'),
                             b.span({'class': 'employee-contrib'}, 'Employees'),
                             b.span({'class': 'pac-contrib'}, 'PAC'),
                             b.span({'class': 'total-contrib'}, 'Total')),
                         contributors,
                         function(idx, c){
                             b.li({'class': 'contributor'},
                                 b.span({'class': 'contributor-name'}, c.name),
                                 b.span({'class': 'employee-contrib money'}, c.employee_amount),
                                 b.span({'class': 'pac-contrib money'}, c.direct_amount),
                                 b.span({'class': 'total-contrib money'}, c.total_amount));
                         });
                }).appendTo(options.get('target'));
                
                $(options.get('target')).find('span.money').formatCurrency({roundToDecimalPlace: 0});
            };

            _FetchTopContributors(options.get('recipient'))
            .done(display_top_contributors);
        };

        that.Lookup = Lookup;
        that.EntityOverview = EntityOverview;
        that.FetchTopIndustries = FetchTopIndustries;
        that.FetchTopContributors = FetchTopContributors;
        that.ContributorsWidget = ContributorsWidget;
        that.IndustriesWidget = IndustriesWidget;
        return this;
    };
})(jQuery);
