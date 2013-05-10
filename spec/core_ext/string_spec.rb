#encoding: UTF-8
require 'spec_helper'

describe String do
  it 'removes accents in text' do
    'Niña'.unaccent.should == 'Nina'
    'Ångstrom'.unaccent.should == 'Angstrom'
    'Noëlle'.unaccent.should == 'Noelle'
  end
end