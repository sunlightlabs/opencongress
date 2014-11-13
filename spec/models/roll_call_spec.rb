# == Schema Information
#
# Table name: roll_calls
#
#  id                  :integer          not null, primary key
#  number              :integer
#  where               :string(255)
#  date                :datetime
#  updated             :datetime
#  roll_type           :text
#  question            :text
#  required            :string(255)
#  result              :string(255)
#  bill_id             :integer
#  amendment_id        :integer
#  filename            :string(255)
#  ayes                :integer          default(0)
#  nays                :integer          default(0)
#  abstains            :integer          default(0)
#  presents            :integer          default(0)
#  democratic_position :boolean
#  republican_position :boolean
#  is_hot              :boolean          default(FALSE)
#  title               :string(255)
#  hot_date            :datetime
#  page_views_count    :integer
#  session             :integer
#

require 'spec_helper'

describe RollCall do
end
