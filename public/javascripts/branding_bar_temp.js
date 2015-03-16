(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){

// require('es5-shim');

var event = require('./util/event'),
    dom = require('./util/dom'),
    ajax = require('./util/ajax'),
    panelTemplate = require('./template/panel'),
    barTemplate = require('./template/bar'),
    donationTemplate = require('./template/barDonate'),
    modalTemplate = require('./template/modalDonate');


/*
 * Return the namespace that all html, css and js should use
 * This is a function so as to be a little less mutable
 */
function namespace() {
  return 'bb';
}

function version() {
  return '0.4.0';
}

function s3Version() {
  return parseFloat(version()).toString();
}

function render(tmpl, ctx) {
  ctx || (ctx = {});
  ctx.namespace = namespace();
  ctx.version = version();
  ctx.s3Version = s3Version();
  return tmpl.replace(/\{\{ ?([\w\d_]+) ?\}\}/gi, function(tag, match) {
    return ctx[match] || '';
  });
}

function join(url, email, zipcode) {
  var data = {
    response: 'json',
    email: email,
    zipcode: zipcode
  };
  ajax.post('https://sunlightfoundation.com/join/', data, function(err, resp) {
    if (err) {
      // resp is a string of err message
      var emailFormError = document.querySelector('.' + namespace() + '_email-form-fail');
      toggle(emailFormError, {
        add: 'is-true'
      });
    } else {
      var respData = JSON.parse(resp);
      var url = 'https://sunlightfoundation.com' + respData.redirect;

      var emailForm = document.querySelector('.' + namespace() + '_email-form');
      toggle(emailForm, {
        add: 'is-hidden'
      });

      var emailFormError = document.querySelector('.' + namespace() + '_email-form-fail');
      toggle(emailFormError, {
        remove: 'is-true'
      });

      var emailFormSuccess = document.querySelector('.' + namespace() + '_email-form-success');
      toggle(emailFormSuccess, {
        add: 'is-true'
      });

      var emailSucceessUrl = document.querySelector('.bb_email-sucess-url');
      emailSucceessUrl.href = url;
    }
  });
}

var toggle = function (els, opts) {
  if (typeof opts.toggle === 'string'){ opts.toggle = [opts.toggle]; }
  if (typeof opts.add === 'string'){ opts.add = [opts.add]; }
  if (typeof opts.remove === 'string'){ opts.remove = [opts.remove]; }
  if (typeof els.length === 'undefined') { els = [els]; }
  var i, j;
  for(i=0; i<els.length; i++){
    if (opts.toggle) {
      for (j=0; j<opts.toggle.length; j++){
        dom.toggleClass(els[i], opts.toggle[j]);
      }
    }
    opts.add && dom.addClass(els[i], opts.add.join(' '));
    if (opts.remove) {
      for (j=0; j<opts.remove.length; j++){
        dom.removeClass(els[i], opts.remove[j]);
      }
    }
  }
};

var labelize = function(name) {
  if (name === 'cvc') {
    name = 'CVC';
  } else if (name === 'amount_other') {
    name = 'Amount';
  } else {
    var properCase = function(txt) {
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    }
    name = name.replace('_', ' ')
               .replace('-', '. ')
               .replace(/\w\S*/g, properCase);
  }
  return name;
};

var validateRequired = function($form, fieldNames, attr) {
  attr = attr || 'name';
  var errors = [];
  for (var i = 0; i < fieldNames.length; i++) {
    var fieldName = fieldNames[i];
    var $elem = $form.querySelector('[' + attr + '=' + fieldName + ']');
    if (!$elem.value) {
      errors.push(labelize(fieldName) + ' is a required field');
      dom.addClass($elem, 'bb-input_error');
    } else {
      dom.removeClass($elem, 'bb-input_error');
    }
  }
  return errors;
};

var displayErrors = function($container, errors) {
  var $list = document.createElement('ul');
  dom.addClass($list, 'bb-error_list');
  for (var i = 0; i < errors.length; i++) {
    var $item = document.createElement('li');
    $item.innerHTML = errors[i];
    $list.appendChild($item);
  }
  $container.appendChild($list);
  dom.show($container);
}

var formatAmount = function(amount) {f
  if (amount.value) {
    amount.value = parseFloat(amount.value).toFixed(2);
    return amount.value;
  }
};

var stripeResponseHandler = function(status, response) {

  var $form = document.querySelector('#bb-transaction-form');
  var $errContainer = $form.querySelector('.bb-modal-form-step-2 .bb-error-message');
  dom.empty($errContainer);

  if (response.error) {

    displayErrors($errContainer, [response.error.message]);
    window.console && console.log(response.error.message);

  } else {

    var token = response.id;
    var $input = document.createElement('input');
    $input.type = 'hidden';
    $input.name = 'stripe_token';
    $input.value = token;
    $form.appendChild($input);

    var data = {
      email: 'jcarbaugh@gmail.com',
      first_name: 'Jeremy',
      last_name: 'Carbaugh',
      stripe_token: $form.querySelector('[name=stripe_token]').value
    };

    var data = dom.serializeForm($form);
    if (!data.amount) {
      data.amount = data.amount_other;
    }
    delete data.amount_other;

    dom.hide($errContainer);

    var step2 = document.querySelectorAll('.bb-modal-form-step-2');
    var step3 = document.querySelectorAll('.bb-modal-form-step-3');

    toggle(step2, {toggle: 'is-active'});
    toggle(step3, {toggle: 'is-active'});

    var url = 'https://sunlightfoundation.com/engage/donate/remote/';
    ajax.post(url, data, function(err, resp) {
      var progress = document.querySelector('.bb-modal-message-progress');
      var thanks = document.querySelector('.bb-modal-message-thankyou');
      toggle(progress, {toggle: 'is-hidden'});
      toggle(thanks, {toggle: 'is-active'});
    });

  }
};

function loadBrandingBar() {
  var bar = document.querySelector('[data-' + namespace() + '-brandingbar]');
  if (bar) {
    var panel = document.querySelector('#' + namespace() + '_panel');
    var url = 'https://sunlightfoundation.com/brandingbar/';
    // var propertyId = bar.getAttribute('data-' + namespace() + '-property-id');
    var loadingStylesheet = ajax.conditionalGet('link', 'https://s3.amazonaws.com/sunlight-cdn/brandingbar/' + s3Version() + '/css/brandingbar.min.css.gz', ['brandingbar.css', 'brandingbar.min.css', 'brandingbar.min.css.gz']);
    var loadingDefaultStylesheet = false;
    // // comment this line in to load the twitter widgets platform
    // var loadingTwitter = ajax.conditionalGet('script', 'https://platform.twitter.com/widgets.js', 'platform.twitter.com/widgets.js');

    // Set up bar
    if(!bar.innerHTML) {
      bar.innerHTML = render(barTemplate);
      loadingDefaultStylesheet = ajax.conditionalGet('link', 'https://s3.amazonaws.com/sunlight-cdn/brandingbar/' + s3Version() + '/css/brandingbar-default.min.css.gz', ['brandingbar-default.css', 'brandingbar-default.min.css', 'brandingbar-default.min.css.gz']);
    }
    // Set up panel
    if (!panel) {
      panel = document.createElement('div');
      if (loadingStylesheet) {
        panel.style.display = "none";
        setTimeout(function(){
          panel.style.display = "";
        }, 750);
      }
      panel.id = namespace() + '_panel';
      bar.parentElement.insertBefore(panel, bar);
    }
    if (!panel.innerHTML) {
      panel.innerHTML = render(panelTemplate);
    }

    var brandingPane = document.querySelector('.' + namespace() + '_wrapper');
    var brandingBarTriggers = document.querySelectorAll('[data-' + namespace() + '-toggle="' + '.' + namespace() + '_wrapper"]');
    var panelTriggers = panel.querySelectorAll('.' + namespace() + '_tools-heading');
    var panels = panel.querySelectorAll('.' + namespace() + '_tools-details');

    // Bind events to show/hide the top panel
    event.on(brandingBarTriggers, 'click', function(ev){
      ev.preventDefault();
      toggle(brandingPane, {toggle: 'is-active'});
    });

    // Bind events to show/hide the tools panels
    event.on(panelTriggers, 'click', function(ev){
      var panelToShow = document.querySelector(this.getAttribute('data-' + namespace() + '-toggle'));
      ev.preventDefault();
      if (typeof panelToShow === 'undefined') { return; }

      toggle(panelTriggers, {
        toggle: 'is-inactive'
      });
      toggle(panels, {
        add: 'is-hidden',
        remove: namespace() + '_fade-animation'
      });
      toggle(panelToShow, {
        add: namespace() + '_fade-animation',
        remove: 'is-hidden'
      });
    });

    // Ajax the signup form if cors support was detected
    if (ajax.supportsCORS()) {
      var form = document.querySelector('.' + namespace() + '_email-form');
      event.addEventListener(form, 'submit', function(ev) {
        ev.preventDefault();
        var email = form.querySelector('input[name=email]').value;
        var zipcode = form.querySelector('input[name=zipcode]').value;
        window.console && console.log(email + " " + zipcode);
        join('https://sunlightfoundation.com/subscribe/', email, zipcode);
      });
    }
  }
}

function loadDonationBar(stripeKey) {
  var bar = document.querySelector('[data-' + namespace() + '-brandingbar]');
  var body = document.querySelector('body');
  if (bar) {
    // var panel = document.querySelector('#' + namespace() + '_panel');

    var stripeTag = document.createElement('script');
    document.querySelector('head').appendChild(stripeTag);
    stripeTag.onload = function(e) {
      Stripe.setPublishableKey(stripeKey);
    };
    stripeTag.src = 'https://js.stripe.com/v2/';

    var loadingStylesheet = ajax.conditionalGet('link', 'https://s3.amazonaws.com/sunlight-cdn/brandingbar/' + s3Version() + '/css/donatebar.min.css.gz', ['donatebar.css', 'donatebar.min.css', 'donatebar.min.css.gz']);
    var loadingDefaultStylesheet = false;

    // Set up bar
    if(!bar.innerHTML) {
      bar.innerHTML = render(donationTemplate);
    }

    // Set up modal

    modal = document.createElement('div');
    bar.parentElement.insertBefore(modal, bar);

    modal.innerHTML = render(modalTemplate);


    var donateButton = document.querySelectorAll('.js-modal-open');
    var modalClose = document.querySelectorAll('.js-modal-close');
    var overlay = document.querySelector('.bb-overlay');
    var modal = document.querySelector('.bb-modal_donation');
    var modalPrompt = document.querySelector('.bb-modal_initial-prompt');

    var step1 = document.querySelectorAll('.bb-modal-form-step-1');
    var step2 = document.querySelectorAll('.bb-modal-form-step-2');
    var step3 = document.querySelectorAll('.bb-modal-form-step-3');

    var nextFrame1 = document.querySelectorAll('.bb-modal-form-step-1 .js-next-frame');
    var nextFrame2 = document.querySelectorAll('.bb-modal-form-step-2 .js-next-frame');

    var prevFrame2 = document.querySelectorAll('.bb-modal-form-step-2 .js-prev-frame');

    function resetDonationForm() {
      // clear form input fields
      var formInput = document.querySelectorAll('.bb-input:not([type="radio"])');

      for (var i = 0; i < formInput.length; i++) {
        formInput[i].value = '';
      }

      // clear form input error styling
      var formInputErrors = document.querySelectorAll('.bb-input_error');
      dom.removeClass(formInputErrors, 'bb-input_error');

      // clear form error message
      var formErrorMessage = document.querySelector('.bb-error-message');
      dom.hide(formErrorMessage);

      // reset form steps after modal is hidden
      setTimeout(function() {
        dom.removeClass(step1, 'is-active');
        dom.removeClass(step2, 'is-active');
        dom.removeClass(step3, 'is-active');
      }, 300);
    }

    // open donate modal
    event.on(donateButton, 'click', function(e){
      e.preventDefault ? e.preventDefault() : e.returnValue = false;
      modal.style.visibility = '';
      dom.addClass(overlay, 'is-active');
      dom.addClass(modal, 'is-active');
      dom.addClass(step1, 'is-active');
    });

    // close donate modal
    event.on(modalClose, 'click', function(e){
      e.preventDefault ? e.preventDefault() : e.returnValue = false;
      dom.removeClass(overlay, 'is-active');
      dom.removeClass(modal, 'is-active');

      resetDonationForm();
    });

    // custom donation amount setup
    var customAmountField = document.querySelectorAll('.bb-input_other-amount');
    var customAmountRadio = document.querySelector('.bb-input[data-radio-custom]');

    // select correct radio button when custom amount is clicked
    event.on(customAmountField, 'click', function(e){
      customAmountRadio.checked = true;
    });

    // format value in custom amount field
    event.on(customAmountField, 'change', function(e) {
      var amount = document.querySelector('input[name=amount_other]');
      formatAmount(amount);

    // set radio value to formatted value
      customAmountRadio.value = formatAmount(amount);
    });


    // proceed to next steps

    // step 1
    event.on(nextFrame1, 'click', function(e) {

      // grab donation amount from checked radio
      var donationRadios = document.getElementsByName('amount');

      for (var i = 0; i < donationRadios.length; i++) {
          if (donationRadios[i].checked) {
              var donationValue = donationRadios[i].value;

              // update donation amount in messages
              var donationUpdate = document.querySelectorAll('.js-val-donation');
              for (var i = 0; i < donationUpdate.length; i++) {
                donationUpdate[i].innerHTML = '$' + donationValue;
                console.log('amount updated: ' + donationValue);
              }
              break;
          }
      }

      var errors = [];
      var $form = document.querySelector('#bb-transaction-form');
      var $amountOther = document.querySelector('.bb-input_other-amount');
      var fieldNames = ['first_name', 'last_name', 'address', 'city', 'state', 'zipcode'];

      dom.removeClass($amountOther, 'bb-input_error');
      if ($form.elements['amount'].value === 'custom') {
        fieldNames.push('amount_other')
      }

      errors = errors.concat(validateRequired($form, fieldNames));

      var $errContainer = $form.querySelector('.bb-modal-form-step-1 .bb-error-message');
      dom.empty($errContainer);
      if (errors.length > 0) {
        displayErrors($errContainer, errors);
      } else {
        dom.hide($errContainer);
        toggle(step1, {toggle: 'is-active'});
        toggle(step2, {toggle: 'is-active'});
      }

    });

    // step 2
    event.on(nextFrame2, 'click', function(e) {
      // grab email address to populate message
      var emailAddress = document.querySelector('.bb-input[data-input-email]').value;
      document.querySelector('.js-val-email').innerHTML = emailAddress.toString();

      var $form = document.querySelector('#bb-transaction-form');
      var propertyId = bar.getAttribute('data-' + namespace() + '-property-id');
      if (propertyId) {
        var $elem = document.createElement('input');
        $elem.type = 'hidden';
        $elem.name = 'source';
        $elem.value = propertyId;
        $form.appendChild($elem);
      }

      var errors = [];
      errors = errors.concat(validateRequired($form, ['email']));
      errors = errors.concat(validateRequired($form, ['number', 'exp-month', 'exp-year', 'cvc'], 'data-stripe'));

      var $errContainer = $form.querySelector('.bb-modal-form-step-2 .bb-error-message');
      dom.empty($errContainer);
      if (errors.length > 0) {
        displayErrors($errContainer, errors);
      } else {
        dom.hide($errContainer);
        Stripe.card.createToken($form, stripeResponseHandler);
      }

    });

    event.on(prevFrame2, 'click', function(e) {
      toggle(step2, {toggle: 'is-active'});
      toggle(step1, {toggle: 'is-active'});
    });

    var triggerAdditionalFields = document.querySelectorAll('.js-trigger-note');
    var additionalFields = document.querySelector('.bb-form-additional-fields');

    event.on(triggerAdditionalFields, 'change', function() {
        toggle(additionalFields, {toggle: 'is-active'});
    });

  }
}

function loadBar() {
  var url = 'https://sunlightfoundation.com/engage/brandingbar/config/';
  ajax.get(url, function(err, content) {
    if (content && content !== '') {
      var data = JSON.parse(content);
      if (data.type === 'donation') {
        loadDonationBar(data.stripe.key);
      } else {
        loadBrandingBar();
      }
    } else {
      loadBrandingBar();
    }
  });
}

loadBar();

},{"./template/bar":3,"./template/barDonate":4,"./template/modalDonate":5,"./template/panel":6,"./util/ajax":7,"./util/dom":8,"./util/event":9,"es5-shim":2}],2:[function(require,module,exports){
/*!
 * https://github.com/es-shims/es5-shim
 * @license es5-shim Copyright 2009-2014 by contributors, MIT License
 * see https://github.com/es-shims/es5-shim/blob/master/LICENSE
 */

// vim: ts=4 sts=4 sw=4 expandtab

//Add semicolon to prevent IIFE from being passed as argument to concated code.
;

// UMD (Universal Module Definition)
// see https://github.com/umdjs/umd/blob/master/returnExports.js
(function (root, factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD. Register as an anonymous module.
        define(factory);
    } else if (typeof exports === 'object') {
        // Node. Does not work with strict CommonJS, but
        // only CommonJS-like enviroments that support module.exports,
        // like Node.
        module.exports = factory();
    } else {
        // Browser globals (root is window)
        root.returnExports = factory();
    }
}(this, function () {

/**
 * Brings an environment as close to ECMAScript 5 compliance
 * as is possible with the facilities of erstwhile engines.
 *
 * Annotated ES5: http://es5.github.com/ (specific links below)
 * ES5 Spec: http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-262.pdf
 * Required reading: http://javascriptweblog.wordpress.com/2011/12/05/extending-javascript-natives/
 */

// Shortcut to an often accessed properties, in order to avoid multiple
// dereference that costs universally.
var ArrayPrototype = Array.prototype;
var ObjectPrototype = Object.prototype;
var FunctionPrototype = Function.prototype;
var StringPrototype = String.prototype;
var NumberPrototype = Number.prototype;
var array_slice = ArrayPrototype.slice;
var array_splice = ArrayPrototype.splice;
var array_push = ArrayPrototype.push;
var array_unshift = ArrayPrototype.unshift;
var call = FunctionPrototype.call;

// Having a toString local variable name breaks in Opera so use _toString.
var _toString = ObjectPrototype.toString;

var isFunction = function (val) {
    return ObjectPrototype.toString.call(val) === '[object Function]';
};
var isRegex = function (val) {
    return ObjectPrototype.toString.call(val) === '[object RegExp]';
};
var isArray = function isArray(obj) {
    return _toString.call(obj) === "[object Array]";
};
var isString = function isString(obj) {
    return _toString.call(obj) === "[object String]";
};
var isArguments = function isArguments(value) {
    var str = _toString.call(value);
    var isArgs = str === '[object Arguments]';
    if (!isArgs) {
        isArgs = !isArray(value)
            && value !== null
            && typeof value === 'object'
            && typeof value.length === 'number'
            && value.length >= 0
            && isFunction(value.callee);
    }
    return isArgs;
};

var supportsDescriptors = Object.defineProperty && (function () {
    try {
        Object.defineProperty({}, 'x', {});
        return true;
    } catch (e) { /* this is ES3 */
        return false;
    }
}());

// Define configurable, writable and non-enumerable props
// if they don't exist.
var defineProperty;
if (supportsDescriptors) {
    defineProperty = function (object, name, method, forceAssign) {
        if (!forceAssign && (name in object)) { return; }
        Object.defineProperty(object, name, {
            configurable: true,
            enumerable: false,
            writable: true,
            value: method
        });
    };
} else {
    defineProperty = function (object, name, method, forceAssign) {
        if (!forceAssign && (name in object)) { return; }
        object[name] = method;
    };
}
var defineProperties = function (object, map, forceAssign) {
    for (var name in map) {
        if (ObjectPrototype.hasOwnProperty.call(map, name)) {
          defineProperty(object, name, map[name], forceAssign);
        }
    }
};

//
// Util
// ======
//

// ES5 9.4
// http://es5.github.com/#x9.4
// http://jsperf.com/to-integer

function toInteger(n) {
    n = +n;
    if (n !== n) { // isNaN
        n = 0;
    } else if (n !== 0 && n !== (1 / 0) && n !== -(1 / 0)) {
        n = (n > 0 || -1) * Math.floor(Math.abs(n));
    }
    return n;
}

function isPrimitive(input) {
    var type = typeof input;
    return (
        input === null ||
        type === "undefined" ||
        type === "boolean" ||
        type === "number" ||
        type === "string"
    );
}

function toPrimitive(input) {
    var val, valueOf, toStr;
    if (isPrimitive(input)) {
        return input;
    }
    valueOf = input.valueOf;
    if (isFunction(valueOf)) {
        val = valueOf.call(input);
        if (isPrimitive(val)) {
            return val;
        }
    }
    toStr = input.toString;
    if (isFunction(toStr)) {
        val = toStr.call(input);
        if (isPrimitive(val)) {
            return val;
        }
    }
    throw new TypeError();
}

// ES5 9.9
// http://es5.github.com/#x9.9
var toObject = function (o) {
    if (o == null) { // this matches both null and undefined
        throw new TypeError("can't convert " + o + " to object");
    }
    return Object(o);
};

var ToUint32 = function ToUint32(x) {
    return x >>> 0;
};

//
// Function
// ========
//

// ES-5 15.3.4.5
// http://es5.github.com/#x15.3.4.5

function Empty() {}

defineProperties(FunctionPrototype, {
    bind: function bind(that) { // .length is 1
        // 1. Let Target be the this value.
        var target = this;
        // 2. If IsCallable(Target) is false, throw a TypeError exception.
        if (!isFunction(target)) {
            throw new TypeError("Function.prototype.bind called on incompatible " + target);
        }
        // 3. Let A be a new (possibly empty) internal list of all of the
        //   argument values provided after thisArg (arg1, arg2 etc), in order.
        // XXX slicedArgs will stand in for "A" if used
        var args = array_slice.call(arguments, 1); // for normal call
        // 4. Let F be a new native ECMAScript object.
        // 11. Set the [[Prototype]] internal property of F to the standard
        //   built-in Function prototype object as specified in 15.3.3.1.
        // 12. Set the [[Call]] internal property of F as described in
        //   15.3.4.5.1.
        // 13. Set the [[Construct]] internal property of F as described in
        //   15.3.4.5.2.
        // 14. Set the [[HasInstance]] internal property of F as described in
        //   15.3.4.5.3.
        var binder = function () {

            if (this instanceof bound) {
                // 15.3.4.5.2 [[Construct]]
                // When the [[Construct]] internal method of a function object,
                // F that was created using the bind function is called with a
                // list of arguments ExtraArgs, the following steps are taken:
                // 1. Let target be the value of F's [[TargetFunction]]
                //   internal property.
                // 2. If target has no [[Construct]] internal method, a
                //   TypeError exception is thrown.
                // 3. Let boundArgs be the value of F's [[BoundArgs]] internal
                //   property.
                // 4. Let args be a new list containing the same values as the
                //   list boundArgs in the same order followed by the same
                //   values as the list ExtraArgs in the same order.
                // 5. Return the result of calling the [[Construct]] internal
                //   method of target providing args as the arguments.

                var result = target.apply(
                    this,
                    args.concat(array_slice.call(arguments))
                );
                if (Object(result) === result) {
                    return result;
                }
                return this;

            } else {
                // 15.3.4.5.1 [[Call]]
                // When the [[Call]] internal method of a function object, F,
                // which was created using the bind function is called with a
                // this value and a list of arguments ExtraArgs, the following
                // steps are taken:
                // 1. Let boundArgs be the value of F's [[BoundArgs]] internal
                //   property.
                // 2. Let boundThis be the value of F's [[BoundThis]] internal
                //   property.
                // 3. Let target be the value of F's [[TargetFunction]] internal
                //   property.
                // 4. Let args be a new list containing the same values as the
                //   list boundArgs in the same order followed by the same
                //   values as the list ExtraArgs in the same order.
                // 5. Return the result of calling the [[Call]] internal method
                //   of target providing boundThis as the this value and
                //   providing args as the arguments.

                // equiv: target.call(this, ...boundArgs, ...args)
                return target.apply(
                    that,
                    args.concat(array_slice.call(arguments))
                );

            }

        };

        // 15. If the [[Class]] internal property of Target is "Function", then
        //     a. Let L be the length property of Target minus the length of A.
        //     b. Set the length own property of F to either 0 or L, whichever is
        //       larger.
        // 16. Else set the length own property of F to 0.

        var boundLength = Math.max(0, target.length - args.length);

        // 17. Set the attributes of the length own property of F to the values
        //   specified in 15.3.5.1.
        var boundArgs = [];
        for (var i = 0; i < boundLength; i++) {
            boundArgs.push("$" + i);
        }

        // XXX Build a dynamic function with desired amount of arguments is the only
        // way to set the length property of a function.
        // In environments where Content Security Policies enabled (Chrome extensions,
        // for ex.) all use of eval or Function costructor throws an exception.
        // However in all of these environments Function.prototype.bind exists
        // and so this code will never be executed.
        var bound = Function("binder", "return function (" + boundArgs.join(",") + "){return binder.apply(this,arguments)}")(binder);

        if (target.prototype) {
            Empty.prototype = target.prototype;
            bound.prototype = new Empty();
            // Clean up dangling references.
            Empty.prototype = null;
        }

        // TODO
        // 18. Set the [[Extensible]] internal property of F to true.

        // TODO
        // 19. Let thrower be the [[ThrowTypeError]] function Object (13.2.3).
        // 20. Call the [[DefineOwnProperty]] internal method of F with
        //   arguments "caller", PropertyDescriptor {[[Get]]: thrower, [[Set]]:
        //   thrower, [[Enumerable]]: false, [[Configurable]]: false}, and
        //   false.
        // 21. Call the [[DefineOwnProperty]] internal method of F with
        //   arguments "arguments", PropertyDescriptor {[[Get]]: thrower,
        //   [[Set]]: thrower, [[Enumerable]]: false, [[Configurable]]: false},
        //   and false.

        // TODO
        // NOTE Function objects created using Function.prototype.bind do not
        // have a prototype property or the [[Code]], [[FormalParameters]], and
        // [[Scope]] internal properties.
        // XXX can't delete prototype in pure-js.

        // 22. Return F.
        return bound;
    }
});

// _Please note: Shortcuts are defined after `Function.prototype.bind` as we
// us it in defining shortcuts.
var owns = call.bind(ObjectPrototype.hasOwnProperty);

// If JS engine supports accessors creating shortcuts.
var defineGetter;
var defineSetter;
var lookupGetter;
var lookupSetter;
var supportsAccessors;
if ((supportsAccessors = owns(ObjectPrototype, "__defineGetter__"))) {
    defineGetter = call.bind(ObjectPrototype.__defineGetter__);
    defineSetter = call.bind(ObjectPrototype.__defineSetter__);
    lookupGetter = call.bind(ObjectPrototype.__lookupGetter__);
    lookupSetter = call.bind(ObjectPrototype.__lookupSetter__);
}

//
// Array
// =====
//

// ES5 15.4.4.12
// http://es5.github.com/#x15.4.4.12
var spliceNoopReturnsEmptyArray = (function () {
    var a = [1, 2];
    var result = a.splice();
    return a.length === 2 && isArray(result) && result.length === 0;
}());
defineProperties(ArrayPrototype, {
    // Safari 5.0 bug where .splice() returns undefined
    splice: function splice(start, deleteCount) {
        if (arguments.length === 0) {
            return [];
        } else {
            return array_splice.apply(this, arguments);
        }
    }
}, spliceNoopReturnsEmptyArray);

var spliceWorksWithEmptyObject = (function () {
    var obj = {};
    ArrayPrototype.splice.call(obj, 0, 0, 1);
    return obj.length === 1;
}());
defineProperties(ArrayPrototype, {
    splice: function splice(start, deleteCount) {
        if (arguments.length === 0) { return []; }
        var args = arguments;
        this.length = Math.max(toInteger(this.length), 0);
        if (arguments.length > 0 && typeof deleteCount !== 'number') {
            args = array_slice.call(arguments);
            if (args.length < 2) {
                args.push(this.length - start);
            } else {
                args[1] = toInteger(deleteCount);
            }
        }
        return array_splice.apply(this, args);
    }
}, !spliceWorksWithEmptyObject);

// ES5 15.4.4.12
// http://es5.github.com/#x15.4.4.13
// Return len+argCount.
// [bugfix, ielt8]
// IE < 8 bug: [].unshift(0) === undefined but should be "1"
var hasUnshiftReturnValueBug = [].unshift(0) !== 1;
defineProperties(ArrayPrototype, {
    unshift: function () {
        array_unshift.apply(this, arguments);
        return this.length;
    }
}, hasUnshiftReturnValueBug);

// ES5 15.4.3.2
// http://es5.github.com/#x15.4.3.2
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/isArray
defineProperties(Array, { isArray: isArray });

// The IsCallable() check in the Array functions
// has been replaced with a strict check on the
// internal class of the object to trap cases where
// the provided function was actually a regular
// expression literal, which in V8 and
// JavaScriptCore is a typeof "function".  Only in
// V8 are regular expression literals permitted as
// reduce parameters, so it is desirable in the
// general case for the shim to match the more
// strict and common behavior of rejecting regular
// expressions.

// ES5 15.4.4.18
// http://es5.github.com/#x15.4.4.18
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/array/forEach

// Check failure of by-index access of string characters (IE < 9)
// and failure of `0 in boxedString` (Rhino)
var boxedString = Object("a");
var splitString = boxedString[0] !== "a" || !(0 in boxedString);

var properlyBoxesContext = function properlyBoxed(method) {
    // Check node 0.6.21 bug where third parameter is not boxed
    var properlyBoxesNonStrict = true;
    var properlyBoxesStrict = true;
    if (method) {
        method.call('foo', function (_, __, context) {
            if (typeof context !== 'object') { properlyBoxesNonStrict = false; }
        });

        method.call([1], function () {
            'use strict';
            properlyBoxesStrict = typeof this === 'string';
        }, 'x');
    }
    return !!method && properlyBoxesNonStrict && properlyBoxesStrict;
};

defineProperties(ArrayPrototype, {
    forEach: function forEach(fun /*, thisp*/) {
        var object = toObject(this),
            self = splitString && isString(this) ? this.split('') : object,
            thisp = arguments[1],
            i = -1,
            length = self.length >>> 0;

        // If no callback function or if callback is not a callable function
        if (!isFunction(fun)) {
            throw new TypeError(); // TODO message
        }

        while (++i < length) {
            if (i in self) {
                // Invoke the callback function with call, passing arguments:
                // context, property value, property key, thisArg object
                // context
                fun.call(thisp, self[i], i, object);
            }
        }
    }
}, !properlyBoxesContext(ArrayPrototype.forEach));

// ES5 15.4.4.19
// http://es5.github.com/#x15.4.4.19
// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/map
defineProperties(ArrayPrototype, {
    map: function map(fun /*, thisp*/) {
        var object = toObject(this),
            self = splitString && isString(this) ? this.split('') : object,
            length = self.length >>> 0,
            result = Array(length),
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (!isFunction(fun)) {
            throw new TypeError(fun + " is not a function");
        }

        for (var i = 0; i < length; i++) {
            if (i in self) {
                result[i] = fun.call(thisp, self[i], i, object);
            }
        }
        return result;
    }
}, !properlyBoxesContext(ArrayPrototype.map));

// ES5 15.4.4.20
// http://es5.github.com/#x15.4.4.20
// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/filter
defineProperties(ArrayPrototype, {
    filter: function filter(fun /*, thisp */) {
        var object = toObject(this),
            self = splitString && isString(this) ? this.split('') : object,
            length = self.length >>> 0,
            result = [],
            value,
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (!isFunction(fun)) {
            throw new TypeError(fun + " is not a function");
        }

        for (var i = 0; i < length; i++) {
            if (i in self) {
                value = self[i];
                if (fun.call(thisp, value, i, object)) {
                    result.push(value);
                }
            }
        }
        return result;
    }
}, !properlyBoxesContext(ArrayPrototype.filter));

// ES5 15.4.4.16
// http://es5.github.com/#x15.4.4.16
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/every
defineProperties(ArrayPrototype, {
    every: function every(fun /*, thisp */) {
        var object = toObject(this),
            self = splitString && isString(this) ? this.split('') : object,
            length = self.length >>> 0,
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (!isFunction(fun)) {
            throw new TypeError(fun + " is not a function");
        }

        for (var i = 0; i < length; i++) {
            if (i in self && !fun.call(thisp, self[i], i, object)) {
                return false;
            }
        }
        return true;
    }
}, !properlyBoxesContext(ArrayPrototype.every));

// ES5 15.4.4.17
// http://es5.github.com/#x15.4.4.17
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/some
defineProperties(ArrayPrototype, {
    some: function some(fun /*, thisp */) {
        var object = toObject(this),
            self = splitString && isString(this) ? this.split('') : object,
            length = self.length >>> 0,
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (!isFunction(fun)) {
            throw new TypeError(fun + " is not a function");
        }

        for (var i = 0; i < length; i++) {
            if (i in self && fun.call(thisp, self[i], i, object)) {
                return true;
            }
        }
        return false;
    }
}, !properlyBoxesContext(ArrayPrototype.some));

// ES5 15.4.4.21
// http://es5.github.com/#x15.4.4.21
// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/reduce
var reduceCoercesToObject = false;
if (ArrayPrototype.reduce) {
    reduceCoercesToObject = typeof ArrayPrototype.reduce.call('es5', function (_, __, ___, list) { return list; }) === 'object';
}
defineProperties(ArrayPrototype, {
    reduce: function reduce(fun /*, initial*/) {
        var object = toObject(this),
            self = splitString && isString(this) ? this.split('') : object,
            length = self.length >>> 0;

        // If no callback function or if callback is not a callable function
        if (!isFunction(fun)) {
            throw new TypeError(fun + " is not a function");
        }

        // no value to return if no initial value and an empty array
        if (!length && arguments.length === 1) {
            throw new TypeError("reduce of empty array with no initial value");
        }

        var i = 0;
        var result;
        if (arguments.length >= 2) {
            result = arguments[1];
        } else {
            do {
                if (i in self) {
                    result = self[i++];
                    break;
                }

                // if array contains no values, no initial value to return
                if (++i >= length) {
                    throw new TypeError("reduce of empty array with no initial value");
                }
            } while (true);
        }

        for (; i < length; i++) {
            if (i in self) {
                result = fun.call(void 0, result, self[i], i, object);
            }
        }

        return result;
    }
}, !reduceCoercesToObject);

// ES5 15.4.4.22
// http://es5.github.com/#x15.4.4.22
// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/reduceRight
var reduceRightCoercesToObject = false;
if (ArrayPrototype.reduceRight) {
    reduceRightCoercesToObject = typeof ArrayPrototype.reduceRight.call('es5', function (_, __, ___, list) { return list; }) === 'object';
}
defineProperties(ArrayPrototype, {
    reduceRight: function reduceRight(fun /*, initial*/) {
        var object = toObject(this),
            self = splitString && isString(this) ? this.split('') : object,
            length = self.length >>> 0;

        // If no callback function or if callback is not a callable function
        if (!isFunction(fun)) {
            throw new TypeError(fun + " is not a function");
        }

        // no value to return if no initial value, empty array
        if (!length && arguments.length === 1) {
            throw new TypeError("reduceRight of empty array with no initial value");
        }

        var result, i = length - 1;
        if (arguments.length >= 2) {
            result = arguments[1];
        } else {
            do {
                if (i in self) {
                    result = self[i--];
                    break;
                }

                // if array contains no values, no initial value to return
                if (--i < 0) {
                    throw new TypeError("reduceRight of empty array with no initial value");
                }
            } while (true);
        }

        if (i < 0) {
            return result;
        }

        do {
            if (i in self) {
                result = fun.call(void 0, result, self[i], i, object);
            }
        } while (i--);

        return result;
    }
}, !reduceRightCoercesToObject);

// ES5 15.4.4.14
// http://es5.github.com/#x15.4.4.14
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/indexOf
var hasFirefox2IndexOfBug = Array.prototype.indexOf && [0, 1].indexOf(1, 2) !== -1;
defineProperties(ArrayPrototype, {
    indexOf: function indexOf(sought /*, fromIndex */ ) {
        var self = splitString && isString(this) ? this.split('') : toObject(this),
            length = self.length >>> 0;

        if (!length) {
            return -1;
        }

        var i = 0;
        if (arguments.length > 1) {
            i = toInteger(arguments[1]);
        }

        // handle negative indices
        i = i >= 0 ? i : Math.max(0, length + i);
        for (; i < length; i++) {
            if (i in self && self[i] === sought) {
                return i;
            }
        }
        return -1;
    }
}, hasFirefox2IndexOfBug);

// ES5 15.4.4.15
// http://es5.github.com/#x15.4.4.15
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/lastIndexOf
var hasFirefox2LastIndexOfBug = Array.prototype.lastIndexOf && [0, 1].lastIndexOf(0, -3) !== -1;
defineProperties(ArrayPrototype, {
    lastIndexOf: function lastIndexOf(sought /*, fromIndex */) {
        var self = splitString && isString(this) ? this.split('') : toObject(this),
            length = self.length >>> 0;

        if (!length) {
            return -1;
        }
        var i = length - 1;
        if (arguments.length > 1) {
            i = Math.min(i, toInteger(arguments[1]));
        }
        // handle negative indices
        i = i >= 0 ? i : length - Math.abs(i);
        for (; i >= 0; i--) {
            if (i in self && sought === self[i]) {
                return i;
            }
        }
        return -1;
    }
}, hasFirefox2LastIndexOfBug);

//
// Object
// ======
//

// ES5 15.2.3.14
// http://es5.github.com/#x15.2.3.14

// http://whattheheadsaid.com/2010/10/a-safer-object-keys-compatibility-implementation
var hasDontEnumBug = !({'toString': null}).propertyIsEnumerable('toString'),
    hasProtoEnumBug = (function () {}).propertyIsEnumerable('prototype'),
    dontEnums = [
        "toString",
        "toLocaleString",
        "valueOf",
        "hasOwnProperty",
        "isPrototypeOf",
        "propertyIsEnumerable",
        "constructor"
    ],
    dontEnumsLength = dontEnums.length;

defineProperties(Object, {
    keys: function keys(object) {
        var isFn = isFunction(object),
            isArgs = isArguments(object),
            isObject = object !== null && typeof object === 'object',
            isStr = isObject && isString(object);

        if (!isObject && !isFn && !isArgs) {
            throw new TypeError("Object.keys called on a non-object");
        }

        var theKeys = [];
        var skipProto = hasProtoEnumBug && isFn;
        if (isStr || isArgs) {
            for (var i = 0; i < object.length; ++i) {
                theKeys.push(String(i));
            }
        } else {
            for (var name in object) {
                if (!(skipProto && name === 'prototype') && owns(object, name)) {
                    theKeys.push(String(name));
                }
            }
        }

        if (hasDontEnumBug) {
            var ctor = object.constructor,
                skipConstructor = ctor && ctor.prototype === object;
            for (var j = 0; j < dontEnumsLength; j++) {
                var dontEnum = dontEnums[j];
                if (!(skipConstructor && dontEnum === 'constructor') && owns(object, dontEnum)) {
                    theKeys.push(dontEnum);
                }
            }
        }
        return theKeys;
    }
});

var keysWorksWithArguments = Object.keys && (function () {
    // Safari 5.0 bug
    return Object.keys(arguments).length === 2;
}(1, 2));
var originalKeys = Object.keys;
defineProperties(Object, {
    keys: function keys(object) {
        if (isArguments(object)) {
            return originalKeys(ArrayPrototype.slice.call(object));
        } else {
            return originalKeys(object);
        }
    }
}, !keysWorksWithArguments);

//
// Date
// ====
//

// ES5 15.9.5.43
// http://es5.github.com/#x15.9.5.43
// This function returns a String value represent the instance in time
// represented by this Date object. The format of the String is the Date Time
// string format defined in 15.9.1.15. All fields are present in the String.
// The time zone is always UTC, denoted by the suffix Z. If the time value of
// this object is not a finite Number a RangeError exception is thrown.
var negativeDate = -62198755200000;
var negativeYearString = "-000001";
var hasNegativeDateBug = Date.prototype.toISOString && new Date(negativeDate).toISOString().indexOf(negativeYearString) === -1;

defineProperties(Date.prototype, {
    toISOString: function toISOString() {
        var result, length, value, year, month;
        if (!isFinite(this)) {
            throw new RangeError("Date.prototype.toISOString called on non-finite value.");
        }

        year = this.getUTCFullYear();

        month = this.getUTCMonth();
        // see https://github.com/es-shims/es5-shim/issues/111
        year += Math.floor(month / 12);
        month = (month % 12 + 12) % 12;

        // the date time string format is specified in 15.9.1.15.
        result = [month + 1, this.getUTCDate(), this.getUTCHours(), this.getUTCMinutes(), this.getUTCSeconds()];
        year = (
            (year < 0 ? "-" : (year > 9999 ? "+" : "")) +
            ("00000" + Math.abs(year)).slice(0 <= year && year <= 9999 ? -4 : -6)
        );

        length = result.length;
        while (length--) {
            value = result[length];
            // pad months, days, hours, minutes, and seconds to have two
            // digits.
            if (value < 10) {
                result[length] = "0" + value;
            }
        }
        // pad milliseconds to have three digits.
        return (
            year + "-" + result.slice(0, 2).join("-") +
            "T" + result.slice(2).join(":") + "." +
            ("000" + this.getUTCMilliseconds()).slice(-3) + "Z"
        );
    }
}, hasNegativeDateBug);


// ES5 15.9.5.44
// http://es5.github.com/#x15.9.5.44
// This function provides a String representation of a Date object for use by
// JSON.stringify (15.12.3).
var dateToJSONIsSupported = false;
try {
    dateToJSONIsSupported = (
        Date.prototype.toJSON &&
        new Date(NaN).toJSON() === null &&
        new Date(negativeDate).toJSON().indexOf(negativeYearString) !== -1 &&
        Date.prototype.toJSON.call({ // generic
            toISOString: function () {
                return true;
            }
        })
    );
} catch (e) {
}
if (!dateToJSONIsSupported) {
    Date.prototype.toJSON = function toJSON(key) {
        // When the toJSON method is called with argument key, the following
        // steps are taken:

        // 1.  Let O be the result of calling ToObject, giving it the this
        // value as its argument.
        // 2. Let tv be toPrimitive(O, hint Number).
        var o = Object(this),
            tv = toPrimitive(o),
            toISO;
        // 3. If tv is a Number and is not finite, return null.
        if (typeof tv === "number" && !isFinite(tv)) {
            return null;
        }
        // 4. Let toISO be the result of calling the [[Get]] internal method of
        // O with argument "toISOString".
        toISO = o.toISOString;
        // 5. If IsCallable(toISO) is false, throw a TypeError exception.
        if (typeof toISO !== "function") {
            throw new TypeError("toISOString property is not callable");
        }
        // 6. Return the result of calling the [[Call]] internal method of
        //  toISO with O as the this value and an empty argument list.
        return toISO.call(o);

        // NOTE 1 The argument is ignored.

        // NOTE 2 The toJSON function is intentionally generic; it does not
        // require that its this value be a Date object. Therefore, it can be
        // transferred to other kinds of objects for use as a method. However,
        // it does require that any such object have a toISOString method. An
        // object is free to use the argument key to filter its
        // stringification.
    };
}

// ES5 15.9.4.2
// http://es5.github.com/#x15.9.4.2
// based on work shared by Daniel Friesen (dantman)
// http://gist.github.com/303249
var supportsExtendedYears = Date.parse('+033658-09-27T01:46:40.000Z') === 1e15;
var acceptsInvalidDates = !isNaN(Date.parse('2012-04-04T24:00:00.500Z')) || !isNaN(Date.parse('2012-11-31T23:59:59.000Z'));
var doesNotParseY2KNewYear = isNaN(Date.parse("2000-01-01T00:00:00.000Z"));
if (!Date.parse || doesNotParseY2KNewYear || acceptsInvalidDates || !supportsExtendedYears) {
    // XXX global assignment won't work in embeddings that use
    // an alternate object for the context.
    Date = (function (NativeDate) {

        // Date.length === 7
        function Date(Y, M, D, h, m, s, ms) {
            var length = arguments.length;
            if (this instanceof NativeDate) {
                var date = length === 1 && String(Y) === Y ? // isString(Y)
                    // We explicitly pass it through parse:
                    new NativeDate(Date.parse(Y)) :
                    // We have to manually make calls depending on argument
                    // length here
                    length >= 7 ? new NativeDate(Y, M, D, h, m, s, ms) :
                    length >= 6 ? new NativeDate(Y, M, D, h, m, s) :
                    length >= 5 ? new NativeDate(Y, M, D, h, m) :
                    length >= 4 ? new NativeDate(Y, M, D, h) :
                    length >= 3 ? new NativeDate(Y, M, D) :
                    length >= 2 ? new NativeDate(Y, M) :
                    length >= 1 ? new NativeDate(Y) :
                                  new NativeDate();
                // Prevent mixups with unfixed Date object
                date.constructor = Date;
                return date;
            }
            return NativeDate.apply(this, arguments);
        }

        // 15.9.1.15 Date Time String Format.
        var isoDateExpression = new RegExp("^" +
            "(\\d{4}|[\+\-]\\d{6})" + // four-digit year capture or sign +
                                      // 6-digit extended year
            "(?:-(\\d{2})" + // optional month capture
            "(?:-(\\d{2})" + // optional day capture
            "(?:" + // capture hours:minutes:seconds.milliseconds
                "T(\\d{2})" + // hours capture
                ":(\\d{2})" + // minutes capture
                "(?:" + // optional :seconds.milliseconds
                    ":(\\d{2})" + // seconds capture
                    "(?:(\\.\\d{1,}))?" + // milliseconds capture
                ")?" +
            "(" + // capture UTC offset component
                "Z|" + // UTC capture
                "(?:" + // offset specifier +/-hours:minutes
                    "([-+])" + // sign capture
                    "(\\d{2})" + // hours offset capture
                    ":(\\d{2})" + // minutes offset capture
                ")" +
            ")?)?)?)?" +
        "$");

        var months = [
            0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365
        ];

        function dayFromMonth(year, month) {
            var t = month > 1 ? 1 : 0;
            return (
                months[month] +
                Math.floor((year - 1969 + t) / 4) -
                Math.floor((year - 1901 + t) / 100) +
                Math.floor((year - 1601 + t) / 400) +
                365 * (year - 1970)
            );
        }

        function toUTC(t) {
            return Number(new NativeDate(1970, 0, 1, 0, 0, 0, t));
        }

        // Copy any custom methods a 3rd party library may have added
        for (var key in NativeDate) {
            Date[key] = NativeDate[key];
        }

        // Copy "native" methods explicitly; they may be non-enumerable
        Date.now = NativeDate.now;
        Date.UTC = NativeDate.UTC;
        Date.prototype = NativeDate.prototype;
        Date.prototype.constructor = Date;

        // Upgrade Date.parse to handle simplified ISO 8601 strings
        Date.parse = function parse(string) {
            var match = isoDateExpression.exec(string);
            if (match) {
                // parse months, days, hours, minutes, seconds, and milliseconds
                // provide default values if necessary
                // parse the UTC offset component
                var year = Number(match[1]),
                    month = Number(match[2] || 1) - 1,
                    day = Number(match[3] || 1) - 1,
                    hour = Number(match[4] || 0),
                    minute = Number(match[5] || 0),
                    second = Number(match[6] || 0),
                    millisecond = Math.floor(Number(match[7] || 0) * 1000),
                    // When time zone is missed, local offset should be used
                    // (ES 5.1 bug)
                    // see https://bugs.ecmascript.org/show_bug.cgi?id=112
                    isLocalTime = Boolean(match[4] && !match[8]),
                    signOffset = match[9] === "-" ? 1 : -1,
                    hourOffset = Number(match[10] || 0),
                    minuteOffset = Number(match[11] || 0),
                    result;
                if (
                    hour < (
                        minute > 0 || second > 0 || millisecond > 0 ?
                        24 : 25
                    ) &&
                    minute < 60 && second < 60 && millisecond < 1000 &&
                    month > -1 && month < 12 && hourOffset < 24 &&
                    minuteOffset < 60 && // detect invalid offsets
                    day > -1 &&
                    day < (
                        dayFromMonth(year, month + 1) -
                        dayFromMonth(year, month)
                    )
                ) {
                    result = (
                        (dayFromMonth(year, month) + day) * 24 +
                        hour +
                        hourOffset * signOffset
                    ) * 60;
                    result = (
                        (result + minute + minuteOffset * signOffset) * 60 +
                        second
                    ) * 1000 + millisecond;
                    if (isLocalTime) {
                        result = toUTC(result);
                    }
                    if (-8.64e15 <= result && result <= 8.64e15) {
                        return result;
                    }
                }
                return NaN;
            }
            return NativeDate.parse.apply(this, arguments);
        };

        return Date;
    })(Date);
}

// ES5 15.9.4.4
// http://es5.github.com/#x15.9.4.4
if (!Date.now) {
    Date.now = function now() {
        return new Date().getTime();
    };
}


//
// Number
// ======
//

// ES5.1 15.7.4.5
// http://es5.github.com/#x15.7.4.5
var hasToFixedBugs = NumberPrototype.toFixed && (
  (0.00008).toFixed(3) !== '0.000'
  || (0.9).toFixed(0) !== '1'
  || (1.255).toFixed(2) !== '1.25'
  || (1000000000000000128).toFixed(0) !== "1000000000000000128"
);

var toFixedHelpers = {
  base: 1e7,
  size: 6,
  data: [0, 0, 0, 0, 0, 0],
  multiply: function multiply(n, c) {
      var i = -1;
      while (++i < toFixedHelpers.size) {
          c += n * toFixedHelpers.data[i];
          toFixedHelpers.data[i] = c % toFixedHelpers.base;
          c = Math.floor(c / toFixedHelpers.base);
      }
  },
  divide: function divide(n) {
      var i = toFixedHelpers.size, c = 0;
      while (--i >= 0) {
          c += toFixedHelpers.data[i];
          toFixedHelpers.data[i] = Math.floor(c / n);
          c = (c % n) * toFixedHelpers.base;
      }
  },
  numToString: function numToString() {
      var i = toFixedHelpers.size;
      var s = '';
      while (--i >= 0) {
          if (s !== '' || i === 0 || toFixedHelpers.data[i] !== 0) {
              var t = String(toFixedHelpers.data[i]);
              if (s === '') {
                  s = t;
              } else {
                  s += '0000000'.slice(0, 7 - t.length) + t;
              }
          }
      }
      return s;
  },
  pow: function pow(x, n, acc) {
      return (n === 0 ? acc : (n % 2 === 1 ? pow(x, n - 1, acc * x) : pow(x * x, n / 2, acc)));
  },
  log: function log(x) {
      var n = 0;
      while (x >= 4096) {
          n += 12;
          x /= 4096;
      }
      while (x >= 2) {
          n += 1;
          x /= 2;
      }
      return n;
  }
};

defineProperties(NumberPrototype, {
    toFixed: function toFixed(fractionDigits) {
        var f, x, s, m, e, z, j, k;

        // Test for NaN and round fractionDigits down
        f = Number(fractionDigits);
        f = f !== f ? 0 : Math.floor(f);

        if (f < 0 || f > 20) {
            throw new RangeError("Number.toFixed called with invalid number of decimals");
        }

        x = Number(this);

        // Test for NaN
        if (x !== x) {
            return "NaN";
        }

        // If it is too big or small, return the string value of the number
        if (x <= -1e21 || x >= 1e21) {
            return String(x);
        }

        s = "";

        if (x < 0) {
            s = "-";
            x = -x;
        }

        m = "0";

        if (x > 1e-21) {
            // 1e-21 < x < 1e21
            // -70 < log2(x) < 70
            e = toFixedHelpers.log(x * toFixedHelpers.pow(2, 69, 1)) - 69;
            z = (e < 0 ? x * toFixedHelpers.pow(2, -e, 1) : x / toFixedHelpers.pow(2, e, 1));
            z *= 0x10000000000000; // Math.pow(2, 52);
            e = 52 - e;

            // -18 < e < 122
            // x = z / 2 ^ e
            if (e > 0) {
                toFixedHelpers.multiply(0, z);
                j = f;

                while (j >= 7) {
                    toFixedHelpers.multiply(1e7, 0);
                    j -= 7;
                }

                toFixedHelpers.multiply(toFixedHelpers.pow(10, j, 1), 0);
                j = e - 1;

                while (j >= 23) {
                    toFixedHelpers.divide(1 << 23);
                    j -= 23;
                }

                toFixedHelpers.divide(1 << j);
                toFixedHelpers.multiply(1, 1);
                toFixedHelpers.divide(2);
                m = toFixedHelpers.numToString();
            } else {
                toFixedHelpers.multiply(0, z);
                toFixedHelpers.multiply(1 << (-e), 0);
                m = toFixedHelpers.numToString() + '0.00000000000000000000'.slice(2, 2 + f);
            }
        }

        if (f > 0) {
            k = m.length;

            if (k <= f) {
                m = s + '0.0000000000000000000'.slice(0, f - k + 2) + m;
            } else {
                m = s + m.slice(0, k - f) + '.' + m.slice(k - f);
            }
        } else {
            m = s + m;
        }

        return m;
    }
}, hasToFixedBugs);


//
// String
// ======
//

// ES5 15.5.4.14
// http://es5.github.com/#x15.5.4.14

// [bugfix, IE lt 9, firefox 4, Konqueror, Opera, obscure browsers]
// Many browsers do not split properly with regular expressions or they
// do not perform the split correctly under obscure conditions.
// See http://blog.stevenlevithan.com/archives/cross-browser-split
// I've tested in many browsers and this seems to cover the deviant ones:
//    'ab'.split(/(?:ab)*/) should be ["", ""], not [""]
//    '.'.split(/(.?)(.?)/) should be ["", ".", "", ""], not ["", ""]
//    'tesst'.split(/(s)*/) should be ["t", undefined, "e", "s", "t"], not
//       [undefined, "t", undefined, "e", ...]
//    ''.split(/.?/) should be [], not [""]
//    '.'.split(/()()/) should be ["."], not ["", "", "."]

var string_split = StringPrototype.split;
if (
    'ab'.split(/(?:ab)*/).length !== 2 ||
    '.'.split(/(.?)(.?)/).length !== 4 ||
    'tesst'.split(/(s)*/)[1] === "t" ||
    'test'.split(/(?:)/, -1).length !== 4 ||
    ''.split(/.?/).length ||
    '.'.split(/()()/).length > 1
) {
    (function () {
        var compliantExecNpcg = /()??/.exec("")[1] === void 0; // NPCG: nonparticipating capturing group

        StringPrototype.split = function (separator, limit) {
            var string = this;
            if (separator === void 0 && limit === 0) {
                return [];
            }

            // If `separator` is not a regex, use native split
            if (_toString.call(separator) !== "[object RegExp]") {
                return string_split.call(this, separator, limit);
            }

            var output = [],
                flags = (separator.ignoreCase ? "i" : "") +
                        (separator.multiline  ? "m" : "") +
                        (separator.extended   ? "x" : "") + // Proposed for ES6
                        (separator.sticky     ? "y" : ""), // Firefox 3+
                lastLastIndex = 0,
                // Make `global` and avoid `lastIndex` issues by working with a copy
                separator2, match, lastIndex, lastLength;
            separator = new RegExp(separator.source, flags + "g");
            string += ""; // Type-convert
            if (!compliantExecNpcg) {
                // Doesn't need flags gy, but they don't hurt
                separator2 = new RegExp("^" + separator.source + "$(?!\\s)", flags);
            }
            /* Values for `limit`, per the spec:
             * If undefined: 4294967295 // Math.pow(2, 32) - 1
             * If 0, Infinity, or NaN: 0
             * If positive number: limit = Math.floor(limit); if (limit > 4294967295) limit -= 4294967296;
             * If negative number: 4294967296 - Math.floor(Math.abs(limit))
             * If other: Type-convert, then use the above rules
             */
            limit = limit === void 0 ?
                -1 >>> 0 : // Math.pow(2, 32) - 1
                ToUint32(limit);
            while (match = separator.exec(string)) {
                // `separator.lastIndex` is not reliable cross-browser
                lastIndex = match.index + match[0].length;
                if (lastIndex > lastLastIndex) {
                    output.push(string.slice(lastLastIndex, match.index));
                    // Fix browsers whose `exec` methods don't consistently return `undefined` for
                    // nonparticipating capturing groups
                    if (!compliantExecNpcg && match.length > 1) {
                        match[0].replace(separator2, function () {
                            for (var i = 1; i < arguments.length - 2; i++) {
                                if (arguments[i] === void 0) {
                                    match[i] = void 0;
                                }
                            }
                        });
                    }
                    if (match.length > 1 && match.index < string.length) {
                        ArrayPrototype.push.apply(output, match.slice(1));
                    }
                    lastLength = match[0].length;
                    lastLastIndex = lastIndex;
                    if (output.length >= limit) {
                        break;
                    }
                }
                if (separator.lastIndex === match.index) {
                    separator.lastIndex++; // Avoid an infinite loop
                }
            }
            if (lastLastIndex === string.length) {
                if (lastLength || !separator.test("")) {
                    output.push("");
                }
            } else {
                output.push(string.slice(lastLastIndex));
            }
            return output.length > limit ? output.slice(0, limit) : output;
        };
    }());

// [bugfix, chrome]
// If separator is undefined, then the result array contains just one String,
// which is the this value (converted to a String). If limit is not undefined,
// then the output array is truncated so that it contains no more than limit
// elements.
// "0".split(undefined, 0) -> []
} else if ("0".split(void 0, 0).length) {
    StringPrototype.split = function split(separator, limit) {
        if (separator === void 0 && limit === 0) { return []; }
        return string_split.call(this, separator, limit);
    };
}

var str_replace = StringPrototype.replace;
var replaceReportsGroupsCorrectly = (function () {
    var groups = [];
    'x'.replace(/x(.)?/g, function (match, group) {
        groups.push(group);
    });
    return groups.length === 1 && typeof groups[0] === 'undefined';
}());

if (!replaceReportsGroupsCorrectly) {
    StringPrototype.replace = function replace(searchValue, replaceValue) {
        var isFn = isFunction(replaceValue);
        var hasCapturingGroups = isRegex(searchValue) && (/\)[*?]/).test(searchValue.source);
        if (!isFn || !hasCapturingGroups) {
            return str_replace.call(this, searchValue, replaceValue);
        } else {
            var wrappedReplaceValue = function (match) {
                var length = arguments.length;
                var originalLastIndex = searchValue.lastIndex;
                searchValue.lastIndex = 0;
                var args = searchValue.exec(match);
                searchValue.lastIndex = originalLastIndex;
                args.push(arguments[length - 2], arguments[length - 1]);
                return replaceValue.apply(this, args);
            };
            return str_replace.call(this, searchValue, wrappedReplaceValue);
        }
    };
}

// ECMA-262, 3rd B.2.3
// Not an ECMAScript standard, although ECMAScript 3rd Edition has a
// non-normative section suggesting uniform semantics and it should be
// normalized across all browsers
// [bugfix, IE lt 9] IE < 9 substr() with negative value not working in IE
var string_substr = StringPrototype.substr;
var hasNegativeSubstrBug = "".substr && "0b".substr(-1) !== "b";
defineProperties(StringPrototype, {
    substr: function substr(start, length) {
        return string_substr.call(
            this,
            start < 0 ? ((start = this.length + start) < 0 ? 0 : start) : start,
            length
        );
    }
}, hasNegativeSubstrBug);

// ES5 15.5.4.20
// whitespace from: http://es5.github.io/#x15.5.4.20
var ws = "\x09\x0A\x0B\x0C\x0D\x20\xA0\u1680\u180E\u2000\u2001\u2002\u2003" +
    "\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\u2028" +
    "\u2029\uFEFF";
var zeroWidth = '\u200b';
var wsRegexChars = "[" + ws + "]";
var trimBeginRegexp = new RegExp("^" + wsRegexChars + wsRegexChars + "*");
var trimEndRegexp = new RegExp(wsRegexChars + wsRegexChars + "*$");
var hasTrimWhitespaceBug = StringPrototype.trim && (ws.trim() || !zeroWidth.trim());
defineProperties(StringPrototype, {
    // http://blog.stevenlevithan.com/archives/faster-trim-javascript
    // http://perfectionkills.com/whitespace-deviations/
    trim: function trim() {
        if (this === void 0 || this === null) {
            throw new TypeError("can't convert " + this + " to object");
        }
        return String(this).replace(trimBeginRegexp, "").replace(trimEndRegexp, "");
    }
}, hasTrimWhitespaceBug);

// ES-5 15.1.2.2
if (parseInt(ws + '08') !== 8 || parseInt(ws + '0x16') !== 22) {
    parseInt = (function (origParseInt) {
        var hexRegex = /^0[xX]/;
        return function parseIntES5(str, radix) {
            str = String(str).trim();
            if (!Number(radix)) {
                radix = hexRegex.test(str) ? 16 : 10;
            }
            return origParseInt(str, radix);
        };
    }(parseInt));
}

}));

},{}],3:[function(require,module,exports){
'use strict';

// Default branding bar template
var template = '' +
'  <div class="branding-bar_container">' +
'    <div class="branding-bar_links">' +
'      <a class="social" href="https://www.facebook.com/sunlightfoundation"><span class="sficon-facebook"></span></a>' +
'      <a class="social" href="https://twitter.com/sunfoundation"><span class="sficon-twitter"></span></a>' +
'      <a class="social" href="https://plus.google.com/+sunlightfoundation"><span class="sficon-google-plus"></span></a>' +
'      <a class="branding-bar_trigger" data-bb-toggle=".bb_wrapper" href="https://sunlightfoundation.com/about/">About Sunlight Foundation</a>' +
'    </div>' +
'    <div class="branding-bar_logo">' +
'      <span class="branding-bar_productof">a product of </span>' +
'      <a class="branding-bar_sunlight-logo" href="https://www.sunlightfoundation.com">Sunlight Foundation</a>' +
'    </div>' +
'  </div>' +
'';

module.exports = template;
},{}],4:[function(require,module,exports){
'use strict';

// Donation bar template
var template = '' +
'<div class="bb-donation-bar_container">' +
'   <div class="bb-donation-message">' +
'        <span class="bb-donation-message_text">' +
'            <strong class="bb-strong">It\'s #GivingTuesday!</strong>' +
'            This year, give a little sunlight.' +
'        </span>' +
'        <button class="bb-button_cta--donate js-modal-open">' +
'           Donate Today' +
'           <svg class="bb-chevron_pulse" xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><path d="M1.5 0l-1.5 1.5 2.5 2.5-2.5 2.5 1.5 1.5 4-4-4-4z" transform="translate(1)" /></svg>' +
'        </button>' +
'        <img class="bb-sunlight-rings" src="https://sunlight-cdn.s3.amazonaws.com/brandingbar/0.4/img/sunlight-rings.svg">' +
'    </div>' +
'   <div class="bb-donation-bar_logo">' +
'       <a class="bb-donation-bar_sunlight-logo" href="https://www.sunlightfoundation.com">Sunlight Foundation</a>' +
'   </div>' +
'</div>' +
'';

module.exports = template;

},{}],5:[function(require,module,exports){
'use strict';

// Donation modal template
var template = '' +
'<div class="bb-overlay"></div>' +
'' +
'<div class="bb-modal_donation" style="display:none;">' +
'    <div class="bb-modal_donation--header">' +
'        <div class="bb-modal-form-step-1">' +
'            <div class="bb-modal--action js-modal-close">' +
'                <span class="bb-modal--action-icon"><svg class="bb-icon_close" xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><path d="M1.41 0l-1.41 1.41.72.72 1.78 1.81-1.78 1.78-.72.69 1.41 1.44.72-.72 1.81-1.81 1.78 1.81.69.72 1.44-1.44-.72-.69-1.81-1.78 1.81-1.81.72-.72-1.44-1.41-.69.72-1.78 1.78-1.81-1.78-.72-.72z" /></svg></span>' +
'            </div>' +
'            <span class="bb-modal--title">This year, give a little sunlight.</span>' +
'            <p class="bb-modal--description">For #GivingTuesday, help us put the <em>giving</em> back into the giving season by supporting Sunlight Foundation!</p>' +
'        </div>' +
'' +
'        <div class="bb-modal-form-step-2">' +
'            <div class="bb-modal--action js-prev-frame">' +
'                <span class="bb-modal--action-icon"><svg class="bb-icon_chevron-left" xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><path d="M4 0l-4 4 4 4 1.5-1.5-2.5-2.5 2.5-2.5-1.5-1.5z" transform="translate(1)" /></svg></span>' +
'            </div>' +
'            <span class="bb-modal--title">You\'re donating <span class="js-val-donation"></span> to Sunlight Foundation</span>' +
'        </div>' +
'' +
'        <div class="bb-modal-form-step-3">' +
'            <div class="bb-modal--action js-modal-close">' +
'                <span class="bb-modal--action-icon"><svg class="bb-icon_close" xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><path d="M1.41 0l-1.41 1.41.72.72 1.78 1.81-1.78 1.78-.72.69 1.41 1.44.72-.72 1.81-1.81 1.78 1.81.69.72 1.44-1.44-.72-.69-1.81-1.78 1.81-1.81.72-.72-1.44-1.41-.69.72-1.78 1.78-1.81-1.78-.72-.72z" /></svg></span>' +
'            </div>' +
'            <span class="bb-modal--title">Thank you for your <span class="js-val-donation"></span> donation!</span>' +
'        </div>' +
'' +
'    </div>' +
'    ' +
'    <div class="bb-modal--content">' +
'' +
'        <form action="https://sunlightfoundation.com/engage/brandingbar/remote/" method="post" id="bb-transaction-form">' +
'        <div class="bb-modal-form-step-1">' +
'' +
'            <div class="bb-form-fieldset_donation">' +
'                <label class="bb-label_radio"><input class="bb-input" type="radio" name="amount" value="10.00" required>$10</input></label>' +
'                <label class="bb-label_radio"><input class="bb-input" type="radio" name="amount" value="25.00" required checked>$25</input></label>' +
'                <label class="bb-label_radio"><input class="bb-input" type="radio" name="amount" value="50.00" required>$50</input></label>' +
'                <label class="bb-label_radio"><input class="bb-input" type="radio" name="amount" value="100.00" required>$100</input></label>' +
'                <label class="bb-label_radio_custom">' +
'                    <input class="bb-input" type="radio" name="amount" value="custom" required data-radio-custom>' +
'                </label>' +
'                <label class="bb-label_radio_custom">' +
'                    <span class="bb-other-amount-prefix">$</span>' +
'                    <input class="bb-input bb-input_other-amount" type="text" name="amount_other" placeholder="Other Amount"></input>' +
'                </label>' +
'            </div>' +
'            <hr class="bb-divider">' +
'            <div class="bb-form-fieldset">' +
'                <div class="bb-form-group fg-5">' +
'                    <label class="bb-label">' +
'                        <span>First Name</span>' +
'                        <input class="bb-input" name="first_name" required></input>' +
'                    </label>' +
'                </div>' +
'' +
'                <div class="bb-form-group fg-5">            ' +
'                    <label class="bb-label">' +
'                        <span>Last Name</span>' +
'                        <input class="bb-input bb-input_no-border-left" name="last_name" required></input>' +
'                    </label>' +
'                </div>' +
'            </div>' +
'' +
'            <div class="bb-form-fieldset">' +
'                <div class="bb-form-group fg-8">' +
'' +
'                    <label class="bb-label">' +
'                        <span>Street Address</span>' +
'                        <input class="bb-input" name="address" required></input>' +
'                    </label>' +
'                </div>' +
'' +
'                <div class="bb-form-group fg-2">' +
'                    <label class="bb-label">' +
'                        <span>Apt/Suite</span>' +
'                        <input class="bb-input bb-input_no-border-left" name="unit"></input>' +
'                    </label>' +
'                </div>' +
'            </div>' +
'            ' +
'            <div class="bb-form-fieldset">' +
'                <div class="bb-form-group fg-4">' +
'                    <label class="bb-label">' +
'                        <span>City</span>' +
'                        <input class="bb-input" name="city" required></input>' +
'                    </label>' +
'                </div>' +
'' +
'                <div class="bb-form-group fg-4">' +
'                    <label class="bb-label">' +
'                        <span>State</span>' +
'                        <input class="bb-input bb-input_no-border-left" name="state" required></input>' +
'                    </label>' +
'                </div>' +
'' +
'                <div class="bb-form-group fg-2">' +
'                    <label class="bb-label">' +
'                        <span>Zipcode</span>' +
'                        <input class="bb-input bb-input_no-border-left" name="zipcode" required></input>' +
'                    </label>' +
'                </div>' +
'            </div>' +
'' +
'            <div class="bb-form-fieldset_btns">' +
'                <div class="bb-error-message">Error Message</div>' +
'                <a class="bb-modal--link-alt js-modal-close" href="">Cancel</a>' +
'                <button class="bb-button_cta--next js-next-frame" type="button">' +
'                   Next' +
'                   <svg class="bb-chevron" xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><path d="M1.5 0l-1.5 1.5 2.5 2.5-2.5 2.5 1.5 1.5 4-4-4-4z" transform="translate(1)" /></svg>' +
'                </button>' +
'            </div>' +
'' +
'        </div> <!-- step1 -->' +
'' +
'        <div class="bb-modal-form-step-2">' +
'' +
'            <div class="bb-form-fieldset">' +
'                <div class="bb-form-group fg-10">' +
'                    <label class="bb-label">' +
'                        <span>Email Address</span>' +
'                        <input class="bb-input" name="email" type="email" required data-input-email></input>' +
'                    </label>' +
'                </div>' +
'            </div>' +
'' +
'            <div class="bb-form-fieldset">' +
'                <div class="bb-form-group fg-6">' +
'                    <label class="bb-label">' +
'                        <span>Card Number</span>' +
'                        <input class="bb-input" data-stripe="number"></input>' +
'                    </label>' +
'                </div>' +
'' +
'                <div class="bb-form-group fg-1">' +
'                    <label class="bb-label">' +
'                        <span>Expires</span>' +
'                        <input class="bb-input bb-input_no-border-left" placeholder="MM" data-stripe="exp-month"></input>' +
'                    </label>' +
'                </div>' +
'' +
'                <div class="bb-form-group fg-1">' +
'                    <label class="bb-label">' +
'                        <span>&nbsp;</span>' +
'                        <input class="bb-input bb-input_no-border-left" placeholder="YY" data-stripe="exp-year"></input>' +
'                    </label>' +
'                </div>' +
'' +
'                <div class="bb-form-group fg-2">' +
'                    <label class="bb-label">' +
'                        <span>CVC</span>' +
'                        <input class="bb-input bb-input_no-border-left" data-stripe="cvc"></input>' +
'                    </label>' +
'                </div>' +
'            </div>' +
'' +
'            <div class="bb-form-fieldset_checkmark">' +
'                <label class="bb-label">' +
'                    <input class="bb-input" type="checkbox" name="signup">I would like email updates from the Sunlight Foundation</input>' +
'                </label>' +
'            </div>' +
'' +
'' +
'            <div class="bb-form-fieldset_checkmark">' +
'                <label class="bb-label">' +
'                    <input class="bb-input js-trigger-note" type="checkbox">Leave a note and other info with my donation</input>' +
'                </label>' +
'            </div>' +
'' +
'            <div class="bb-form-additional-fields">' +
'' +
'                <hr class="bb-divider">' +
'' +
'                <div class="bb-form-fieldset">' +
'                    <div class="bb-form-group fg-10">' +
'                        <label class="bb-label">' +
'                            <span>Note (optional)</span>' +
'                            <textarea class="bb-input bb-input_note bb-modal--link" placeholder="Write a note" name="note"></textarea>' +
'                        </label>' +
'                    </div>' +
'                </div>' +
'' +
'                <div class="bb-form-fieldset">' +
'                    <div class="bb-form-group fg-5">' +
'                        <label class="bb-label">' +
'                            <span>Phone Number (optional)</span>' +
'                            <input class="bb-input" name="phone"></input>' +
'                        </label>' +
'                    </div>' +
'                    <div class="bb-form-group fg-5">' +
'                        <label class="bb-label">' +
'                            <span>Occupation (optional)</span>' +
'                            <input class="bb-input bb-input_no-border-left" name="occupation"></input>' +
'                        </label>' +
'                    </div>' +
'                </div>' +
'            </div>' +
'' +
'            <div class="bb-form-fieldset_btns">' +
'                <div class="bb-error-message">Error Message</div>' +
'                <a class="bb-modal--link-alt js-prev-frame" href="#">Go Back</a>' +
'                <button class="bb-button_cta--next js-next-frame" type="button">' +
'                    Complete Donation' +
'                    <svg class="bb-chevron" xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><path d="M1.5 0l-1.5 1.5 2.5 2.5-2.5 2.5 1.5 1.5 4-4-4-4z" transform="translate(1)" /></svg>' +
'                </button>' +
'            </div>' +
'            ' +
'        </div> <!-- end step 2 -->' +
'' +
'        </form>' +
'        <div class="bb-modal-form-step-3">' +
'           <div class="bb-modal-message-progress">' +
'                <svg class="bb-progress_icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 8 8"><path d="M4 0c-2.2 0-4 1.8-4 4s1.8 4 4 4c1.1 0 2.12-.43 2.84-1.16l-.72-.72c-.54.54-1.29.88-2.13.88-1.66 0-3-1.34-3-3s1.34-3 3-3c.83 0 1.55.36 2.09.91l-1.09 1.09h3v-3l-1.19 1.19c-.72-.72-1.71-1.19-2.81-1.19z"></path></svg>' +
'                <p class="bb-progress_text">Processing your donationâ€¦</p>' +
'           </div>' +
'' +
'            <div class="bb-modal-message-thankyou">' +
'                <p class="bb-thankyou-thankyou_text">Thank you for choosing to support the Sunlight Foundation and participating in the #GivingTuesday movement.</p>' +
'                <p>We\'ve sent an email confirmation and receipt to <strong class="bb-strong"><span class="js-val-email">your email address</span></strong> that you can keep for your records. </p>' +
'                <hr class="bb-divider">' +
'                <p>If you have any questions about your donation, feel free give us a call at <br>(202)742-1520, or email us at <a href="mailto:donors@sunlightfoundation.com" class="bb-modal--link">donors@sunlightfoundation.com</a></p>' +
'            </div>' +
'        </div>' +
'' +
'    </div>' +
'' +
'' +
'    <div class="bb-modal--footer">' +
'        <p>The Sunlight Foundation is a 501(c)(3) nonprofit, transpartisan organization. All contributions are tax deductible. Please review our <a href="http://sunlightfoundation.com/legal/gifts/" target="_blank" class="bb-modal--link">gift acceptance policy</a> for contributions over $250.</p>' +
'    </div>' +
'' +
'</div>' +
'';

module.exports = template;

},{}],6:[function(require,module,exports){
'use strict';

// Default panel template
var template = '' +
'  <button id="{{ namespace }}_close-panel" type="button" data-{{ namespace }}-toggle=".{{ namespace }}_wrapper">&times;</button>' +
'  <div class="{{ namespace }}_panel-container">' +
'    <div class="{{ namespace }}_about">' +
'      <span class="{{ namespace }}_heading">About Sunlight Foundation</span>' +
'      <p class="{{ namespace }}_description">The <a class="{{ namespace }}_link" href="https://sunlightfoundation.com">Sunlight Foundation</a> is a nonpartisan nonprofit that advocates for open government globally and uses technology to make government more accountable to all.</p>' +
'' +
'      <div class="{{ namespace }}_email">' +
'        <span class="{{ namespace }}_heading">Stay informed about our work</span>' +
'        <form class="{{ namespace }}_email-form" action="https://sunlightfoundation.com/join/" method="post">' +
'          <input class="{{ namespace }}_input" type="email" placeholder="email address" name="email">' +
'          <input class="{{ namespace }}_input {{ namespace }}_input-zip" type="text" placeholder="zip code" name="zipcode">' +
'          <button class="{{ namespace }}_submit" type="submit">Submit</button>' +
'          <span class="{{ namespace }}_email-form-fail">Oops, there was an error :(</span>' +
'        </form>' +
'        <div class="bb_email-form-success"> Thanks for subscribing to our updates! <a class="bb_link bb_email-sucess-url" href="">Tell us more about you &raquo;</a></div>' +
'      </div>' +
'    </div>' +
'' +
'    <div class="{{ namespace }}_tools">' +
'      <span class="{{ namespace }}_heading">' +
'        <span class="{{ namespace }}_tools-heading" id="{{ namespace }}_featured-tools-heading" data-{{ namespace }}-toggle="#{{ namespace }}_featured-tools">Related Tools</span>' +
'        <span class="{{ namespace }}_tools-heading is-inactive" id="{{ namespace }}_more-tools-heading" data-{{ namespace }}-toggle="#{{ namespace }}_more-tools">All Tools</span>' +
'      </span>' +
'' +
'      <div id="{{ namespace }}_featured-tools" class="{{ namespace }}_tools-details">' +
'        <ul class="{{ namespace }}_tools-featured">' +
'          <li>' +
'            <a class="{{ namespace }}_tools-logo" href="https://www.opencongress.org">' +
'            <img src="https://sunlight-cdn.s3.amazonaws.com/brandingbar/{{ s3Version }}/img/logo_opencongress.png" alt="Open Congress"/>' +
'            </a>' +
'            <p class="{{ namespace }}_description">' +
'              <a class="{{ namespace }}_link" href="https://www.opencongress.org">OpenCongress</a> allows anyone to follow legislation in Congress, from bill introduction to floor votes. Learn more about the issues you care about.' +
'            </p>' +
'          </li>' +
'          <li>' +
'            <a class="{{ namespace }}_tools-logo" href="https://scout.sunlightfoundation.com">' +
'              <img src="https://sunlight-cdn.s3.amazonaws.com/brandingbar/{{ s3Version }}/img/logo_scout.png" alt="Scout"/>' +
'            </a>' +
'            <p class="{{ namespace }}_description">' +
'              <a class="{{ namespace }}_link" href="https://scout.sunlightfoundation.com">Scout</a> is a rapid notification service that allows anyone to create customized email or text alerts on actions Congress takes on an issue or a specific bill.' +
'            </p>' +
'          </li>' +
'        </ul>' +
'      </div>' +
'      <div id="{{ namespace }}_more-tools" class="{{ namespace }}_tools-details is-hidden">' +
'        <ul class="{{ namespace }}_tools-list">' +
'          <li><a class="{{ namespace }}_link" href="https://www.opencongress.org">OpenCongress</a></li>' +
'          <li><a class="{{ namespace }}_link" href="http://influenceexplorer.com">Influence Explorer</a></li>' +
'          <li><a class="{{ namespace }}_link" href="http://openstates.org">Open States</a></li>' +
'          <li><a class="{{ namespace }}_link" href="https://scout.sunlightfoundation.com">Scout</a></li>' +
'        </ul>' +
'' +
'        <ul class="{{ namespace }}_tools-list">' +
'          <li><a class="{{ namespace }}_link" href="http://churnalism.sunlightfoundation.com">Churnalism</a></li>' +
'          <li><a class="{{ namespace }}_link" href="http://capitolwords.org">Capitol Words</a></li>' +
'          <li><a class="{{ namespace }}_link" href="http://politwoops.sunlightfoundation.com">Politwoops</a></li>' +
'          <li><a class="{{ namespace }}_link" href="http://adhawk.sunlightfoundation.com">Ad Hawk</a></li>' +
'        </ul>' +
'' +
'        <ul class="{{ namespace }}_tools-list">' +
'          <li><a class="{{ namespace }}_link" href="http://politicalpartytime.org">Party Time</a></li>' +
'          <li><a class="{{ namespace }}_link" href="https://scout.sunlightfoundation.com">Scout</a></li>' +
'          <li><a class="{{ namespace }}_link" href="http://docketwrench.sunlightfoundation.com">Docket Wrench</a></li>' +
'          <li><a class="{{ namespace }}_link" href="http://politicaladsleuth.com">Political Ad Sleuth</a></li>' +
'        </ul>' +
'      </div>' +
'    </div>' +
'  </div>' +
'';

module.exports = template;

},{}],7:[function(require,module,exports){
'use strict';

function xhr(method, url, data, callback) {
  var request = new XMLHttpRequest();
  request.open(method, url, true);

  // Some people say this trigger CORS.
  request.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
  if (method === 'POST') {
    request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
  }
  request.onreadystatechange = function () {
    if (this.readyState === 4) {
      if (this.status >= 200 && this.status < 400) {
        callback(null, this.responseText);
      } else {
        callback(this.statusText);
      }
    }
  };
  if (data) {
    request.send(uriSerializer(data));
  } else {
    request.send();
  }
  request = null;
}

function get(url, callback) {
  xhr('GET', url, null, callback);
}

function post(url, data, callback) {
  xhr('POST', url, data, callback);
}

function getJSONP(url, opts, callback) {
  if (typeof opts === 'function') {
    callback = opts;
    opts = null;
  }
  opts || (opts = {});
  opts.callbackParam || (opts.callbackParam = 'callback');
  var scr = document.createElement('script');
  var cb = 'jsonp_' + (new Date()).getTime();
  scr.src = url + (url.match(/\?/) ? '&' : '?') + opts.callbackParam + '=' + cb;
  scr.async = true;
  scr.onload = function () {
    setTimeout(function () {
      delete window[cb];
    }, 0);
  };
  window[cb] = callback;
  document.querySelector('head').appendChild(scr);
}

function supportsCORS() {
  return 'withCredentials' in new XMLHttpRequest();
}

function uriSerializer(obj) {
  var str = [];
  for (var prop in obj) {
    if (obj.hasOwnProperty(prop)) {
      str.push(encodeURIComponent(prop) + "=" + encodeURIComponent(obj[prop]));
    }
  }
  return str.join('&');
}

// Loads a link or script unless one ending with condition is found on the page.
function conditionalGet(tagName, url, condition) {
  var already = false,
      selectors;
  if (typeof condition === 'object' && Object.prototype.toString.call(condition) === '[object Array]') {
    if (tagName == 'script'){
      selectors = condition.map(function(item){
        return tagName + '[src$="' + item + '"]';
      });
    } else {
      selectors = condition.map(function(item){
        return tagName + '[href$="' + item + '"]';
      });
    }
    condition = selectors.join(', ');
    already = document.querySelectorAll(condition).length;
  } else if (typeof condition === 'string'){
    already = document.querySelectorAll(tagName + (tagName == 'script') ? '[src$="' + condition + '"]' : '[href$="' + condition + '"]').length;
  }
  if(already) { return false; }
  var tag = document.createElement(tagName);
  if (tagName == 'script') {
    tag.src = url;
  } else {
    tag.href = url;
    tag.rel = 'stylesheet';
  }
  document.querySelector('head').appendChild(tag);
  return true;
}

module.exports = {
  xhr: xhr,
  get: get,
  post: post,
  getJSONP: getJSONP,
  supportsCORS: supportsCORS,
  uriSerializer: uriSerializer,
  conditionalGet: conditionalGet
};

},{}],8:[function(require,module,exports){
'use strict';

function toggleClass(el, className) {
  if (el.classList) {
    el.classList.toggle(className);
  } else {
    var classes = el.className.split(' ');
    var existingIndex = -1;
    for (var i = classes.length; i--;) {
      if (classes[i] === className) {
        existingIndex = i;
      }
    }
    if (existingIndex >= 0) {
      classes.splice(existingIndex, 1);
    } else {
      classes.push(className);
    }
    el.className = classes.join(' ');
  }
}

function addClassHelper(el, className) {
  if (el.classList) {
    el.classList.add(className);
  } else {
    el.className += ' ' + className;
  }
}

function addClass(el, className) {
  if ((Object.prototype.toString.call(el) === '[object NodeList]')) {
    for(var i = 0; i < el.length; i++) {
      addClassHelper(el[i], className);
    }
  } else {
      addClassHelper(el, className);
  }
}

function removeClassHelper(el, className){
  if (el.classList) {
    el.classList.remove(className);
  } else {
    el.className = el.className.replace(new RegExp('(^|\\b)' + className.split(' ').join('|') + '(\\b|$)', 'gi'), ' ');
  }
}

function removeClass(el, className) {
  if ((Object.prototype.toString.call(el) === '[object NodeList]')) {
    for(var i = 0; i < el.length; i++) {
      removeClassHelper(el[i], className);
    }
  } else {
      removeClassHelper(el, className);
  }
}

function serializeForm(form) {
  var data = {};
  var elems = form.elements;
  for (var i = 0; i < elems.length; i++) {
    var elem = elems[i];
    if (elem.name) {
      if (elem.type === 'button') {
        // ignore
      } else if (elem.type === 'radio' || elem.type === 'checkbox') {
        if (elem.checked) {
          data[elem.name] = elem.value;
        }
      } else {
        data[elem.name] = elem.value;
      }
    }
  }
  return data;
};

function empty(node) {
  while (node.hasChildNodes()) {
    node.removeChild(node.lastChild);
  }
};

function show(node) {
  node.style.display = 'block';
};

function hide(node) {
  node.style.display = 'none';
};

module.exports = {
  toggleClass: toggleClass,
  addClass: addClass,
  removeClass: removeClass,
  serializeForm: serializeForm,
  empty: empty,
  show: show,
  hide: hide
};

},{}],9:[function(require,module,exports){
'use strict';

// Binds a single event.
function addEventListener(el, eventName, handler) {
  if (el.addEventListener) {
    el.addEventListener(eventName, handler);
  } else {
    el.attachEvent('on' + eventName, handler);
  }
}

// Binds events to an array of elements elements.
function on(els, eventName, handler) {
  for (var i = 0; i < els.length; i++) {
    addEventListener(els[i], eventName, handler);
  }
}

module.exports = {
  addEventListener: addEventListener,
  on: on
};

},{}]},{},[1]);