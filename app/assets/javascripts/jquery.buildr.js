(function($, exports){

  var Buildr = exports.Buildr = function(){
    this.stack = [];
    this.elements = [];
    this.tags = Buildr.prototype.tags.concat();
  };

  var isObject = function( obj ) {
    if (Object.prototype.toString.call(obj) !== "[object Object]")
      return false;

    var key;
    for(key in obj){}

    return !key || Object.prototype.hasOwnProperty.call(obj, key);
  };

  var isString = function(obj) {
    return Object.prototype.toString.call(obj) === '[object String]';
  };

  //allow jQuery append/prepend methods to accept a Buildr object.
  var original = {};
  var overwrite = ['append', 'prepend'];
  $.each(overwrite, function(idx, method){
    original[method] = $.fn[method];
    $.fn[method] = function(){
      var args  = $.makeArray(arguments);
      var nodes = extractNodes.apply(this, args);
      return original[method].apply(this, nodes);
    };
  });

  var touched = true;
  var untouch = function(){ //don't touch my core jQuery methods!
    $.each(overwrite, function(idx, method){
      $.fn[method] = original[method];
    });
    touched = false;
  };

  var extractNodes = function(){
    var args = $.makeArray(arguments);
    return $.map(args, function(arg){
      return arg instanceof Buildr ? arg.root() : arg;
    });
  };

  var toNodes = function(arr){
    var flattened = $.map(arr, function(obj){
      return obj;
    });
    var nodes = $.map(flattened, function(obj){
      return obj instanceof $ ? obj.get() : obj;
    });
    return nodes;
  };

  var to$ = function(arr){
    var nodes = toNodes(arr);
    return nodes && nodes.length > 0 ? $(nodes) : null;
  };

  var build = function(fn){
    this.elements.splice(0, this.elements.length); //clear elements
    return fn ? to$(fn.call(this, this) || this.root()) : this;
  };

  $.extend(Buildr.prototype, {
    buildr: build,
    build: build,
    tags: [],
    defineTag: function(){
      var args = $.makeArray(arguments), self = this;
      $.each(args, function(idx, tag){
        self.tags.push(tag);
        tag = tag.replace('/','');
        self[tag] = function(){
          var args = $.makeArray(arguments);
          args.unshift(tag);
          return this.tag.apply(this, args);
        };
      });
      return this;
    },
    isSelfClosing: function(tag){
      return this.tags.indexOf(tag + '/') > -1;
    },
    tag: function(){
      var args    = $.makeArray(arguments),
          self    = this,
          tag     = args.shift(),
          getSelf = function(){return self;},
          $el     = this.$ = $.extend($('<'+tag+'>'), {buildr: getSelf, build: getSelf}),
          $outer  = this.stack[0];

      if (touched) $.extend($el, element);

      $outer && $outer.append($el);
      this.elements.push($el);
      element.nest.apply($el, args);

      return $el;
    },
    root: function(){ //root (parentless) elements
      return $.grep(this.elements, function($el){
        return $el.parent().length === 0;
      });
    },
    each: function(items, iterator){
      $.each(items, iterator.bind(this));
      return this;
    },
    extend: function(){
      var mixins = $.makeArray(arguments), self = this;
      $.each(mixins, function(idx, mixin){
        $.each(mixin, function(key, method){
          self[key] = method.bind(self); //maintain binding to builder
        });
      });
      return self;
    }
  });

  //self-closing tags have a trailing slash
  Buildr.prototype.defineTag(
    'a','abbr','acronym','address','article','aside','audio','b','bdi','bdo','big','blockquote','body','button','caption','canvas','command','cite','code','colgroup','datalist','dd','del','details','dfn','div','dl','dt','em','embed','fieldset','figcaption','figure','footer','form','frameset','h1','h2','h3','h4','h5','h6','head','header','hgroup','html','i','iframe','ins','keygen','kbd','label','legend','li','map','mark','meter','nav','noframes','noscript','object','ol','optgroup','option','output','p','pre','progress','q','rp','rt','ruby','samp','section','script','select','small','source','span','strong','style','sub','summary','sup','table','tbody','td','textarea','tfoot','th','thead','time','title','tr','track','tt','ul','var','video','wbr',
    'area/','base/','br/','col/','frame/','hr/','img/','input/','link/','meta/','param/'
  );

  var element = {
    id: function(id){
      this.attr({id: id});
      return this;
    },
    'class': function(classes){
      this.removeClass();
      this.addClass(classes);
      return this;
    },
    nest: function(){
      var $el  = this,
          bldr = this.buildr(),
          args = $.makeArray(arguments),
          tag  = $el.get(0).tagName.toLowerCase(),
          selfClosing = bldr.isSelfClosing(tag);

      var processArg = function(arg){
        if (isObject(arg)) {
          $el.attr(arg); //attributes
        } else if (selfClosing) {
          throw new NestingProhibitedError(tag);
        } else if (arg instanceof $) { //inner element
          $el.append(arg);
        } else if ($.isArray(arg) && $.isFunction(args[0])) { //iterators
          items = arg, iterator = args.shift();
          element.nest.call($el, function(){
            bldr.each(items, iterator);
          });
        } else if (arg.nodeName){
          $el.append(arg);
        } else if ($.isArray(arg) && arg.length > 0 && arg[0].nodeName) { //iterators
          $.each(arg, function(idx, el){
            $el.append(el);
          })
        } else if ($.isFunction(arg)) {
          var result = arg.call(bldr, bldr);
          result && processArg(result);
        } else {
          $el.text(arg.toString());
        }
      };

      bldr.stack.unshift($el);
      while (args.length > 0)
        processArg(args.shift());
      bldr.stack.shift();

      return this;
    }
  };
  element.el = element.nest; //alias

  function NestingProhibitedError(tag) {
    this.name = "NestingProhibitedError";
    this.tag = tag;
  }
  NestingProhibitedError.prototype = Error.prototype;

  $.extend(Buildr, {
    untouch: untouch,
    NestingProhibitedError: NestingProhibitedError
  });

  $.buildr = function() {
    var bldr    = new Buildr();
    var args    = $.makeArray(arguments);
    var built   = [];

    while(args.length > 0){
      var arg = args.shift();
      if ($.isFunction(arg))
        built.push(bldr.buildr(arg));
      else if (isObject(arg))
        bldr.extend(arg);
      else if (isString(arg))
        bldr.defineTag(arg);
    }

    return to$(built) || bldr;
  };

  $.buildr.defineTag = Buildr.prototype.defineTag.bind(Buildr.prototype);
  $.buildr.tags = Buildr.prototype.tags;

  $.fn.buildr = function(){
    var args = $.makeArray(arguments);
    var $el  = $.buildr.apply($.buildr, args);
    return this.append($el);
  };

  //alias to verb
  $.build    || ($.build    = $.buildr);
  $.fn.build || ($.fn.build = $.fn.buildr);

})(jQuery, this);
