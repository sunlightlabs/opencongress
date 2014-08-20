(function(){

    function toTitleCase(str)
    {
        return str.replace(/\b\w+/g, function(txt){return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});
    }

    var InfEx = new IE({apikey: sunlightlabs_key,
                        cycle: current_election_cycle});

    var IndustryContribs = {};
    var Members = [];

    var indDeferreds = member_osids.map(function(osid){
        var def = jQuery.Deferred();

        InfEx.Lookup('urn:crp:recipient', osid.toString())
        .done(function(infex_id){
            InfEx.EntityOverview(infex_id)
            .done(function(member_result){
                Members.push(member_result);
                InfEx.FetchTopIndustries(infex_id)
                .done(function(results){
                    results.forEach(function(ind){
                        var ind_entry = IndustryContribs[ind.name];
                        if (ind_entry === undefined) {
                            ind_entry = IndustryContribs[ind.name] = {};
                        }
                        ind_entry[infex_id] = ind.amount;
                    });
                    def.resolveWith(def, [osid, infex_id]);
                });
            });
        });

        return def.promise();
    });

    var format_money = function (money) {
        return '$' + parseInt(money).toLocaleString();
    };

    var extract_last_name = function (name) {
        var name_parts = name.split(/\s+/);
        var last_part = name_parts[name_parts.length - 1];
        var last_name = (/^\([A-Z]\)$/.test(last_part) == true) ? name_parts[name_parts.length - 2] : last_part;
        return last_name;
    };

    var interpolate_cf_message = function (member, indname, amount, msg) {
        var last_name = extract_last_name(member.name);

        var title = '';
        if (member.metadata.seat == 'federal:senate') {
            title = 'Sen.';
        } else if (member.metadata.seat == 'federal:house') {
            title = 'Rep.';
        }
        msg = msg.replace(':LASTNAME', last_name);
        msg = msg.replace(':TITLE', title);
        msg = msg.replace(':CYCLE', current_election_cycle.toString());
        msg = msg.replace(':INDUSTRY', indname.toLowerCase());
        if (amount === undefined) {
            msg = msg.replace(':AMOUNT', 'no money');
        } else {
            msg = msg.replace(':AMOUNT', format_money(amount));
        }
        return msg;
    };

    jQuery.when.apply(jQuery, indDeferreds)
          .done(function(defs){
              Members.sortBy(function(a, b){ return a.name.localeCompare(b.name); });

              jQuery('div.contribution_data table thead, div.contribution_data table tbody').empty();

              jQuery.build(function(b){
                  b.tr(b.th({'class':'topleft'}),
                       Members, function(ix, member){
                           b.th(extract_last_name(member.name));
                       });
              }).appendTo('div.contribution_data table thead');
                  
              jQuery.each(IndustryContribs, function(name, ind){
                  jQuery.build(function(b){
                      b.tr(b.th({'class':'group_column', 'style':'font-weight:bold'},
                                toTitleCase(name)),
                           Members, function(ix, member){
                               b.td(b.span({'class':'message_builder_clickable'},
                                    function(){
                                        b.div({'class':'money'}, format_money(ind[member.id] || '0'));
                                        b.div({'class':'will_add_text_box', 'style':'display:none'},
                                              b.span({'class':'arrow'}),
                                              b.p('Clicking this will add the following text:'),
                                              b.div({'class':'message_builder_add_text'},
                                                    interpolate_cf_message(member, name, ind[member.id], ':TITLE :LASTNAME, campaign contribution data shows that you received :AMOUNT in the :CYCLE election cycle from the :INDUSTRY industry, which I find relevant to this bill and its issue areas.')));
                               }));
                           });
                  }).appendTo('div.contribution_data table tbody');
              });

              jQuery(".contribution_data .message_builder_clickable").hover(function(){ mbHoverIn(this) }, function(){ mbHoverOut(this) });
              jQuery(".contribution_data .message_builder_clickable").click(function(){ mbAddText(this) });
          });
})();
