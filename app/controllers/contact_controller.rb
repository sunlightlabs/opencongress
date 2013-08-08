class ContactController < ApplicationController
  skip_before_filter :has_district?
end
