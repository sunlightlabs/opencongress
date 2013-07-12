require 'will_paginate/view_helpers'
require 'will_paginate/array'

WillPaginate::ViewHelpers.pagination_options[:renderer] = 'SpanLinkRenderer'
WillPaginate::ViewHelpers.pagination_options[:previous_label] = 'Previous'
WillPaginate::ViewHelpers.pagination_options[:next_label] = 'Next'
