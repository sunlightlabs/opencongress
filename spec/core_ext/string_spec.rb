#encoding: UTF-8
require 'spec_helper'

describe String do
  it 'removes accents in text' do
    expect('Niña'.unaccent).to eq('Nina')
    expect('Ångstrom'.unaccent).to eq('Angstrom')
    expect('Noëlle'.unaccent).to eq('Noelle')
  end
end