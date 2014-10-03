require 'spec_helper'

describe PersonIdentifier do
    before(:each) do 
      @person = people(:person_226043605)
      @person = Person.first
      @person.person_identifiers.create(
        namespace: "fec",
        value: "fecID12345"
      )
    end
    it "should handle single ids in a namespace" do
      expect(@person.person_identifiers.length).to equal(1)
    end
    it "should allow multiple ids in the same namespace" do
      @person.person_identifiers.create(
        namespace: "fec",
        value: "fecIDabcde"
      )
      expect(@person.person_identifiers.length).to equal(2)
    end
    it "should not allow identical ids in the same namespace" do
      pi_original = @person.person_identifiers.create!(
        namespace: "fec",
        value: "fecID12346"
      )
      pi_duplicate = @person.person_identifiers.new(
        namespace: "fec",
        value: "fecID12346"
      )
      expect(pi_duplicate).not_to be_valid
    end
    it "should allow identical ids in different namespaces" do
      pi_original = @person.person_identifiers.create!(
        namespace: "fec",
        value: "fecID12346"
      )
      not_a_duplicate = @person.person_identifiers.new(
        namespace: "notthefec",
        value: "fecID12346"
      )
      expect(not_a_duplicate).to be_valid
    end
    it "should require a value" do
      #No value
      pi = @person.person_identifiers.new(namespace: "fec")
      expect(pi).not_to be_valid
    end
    it "should require a namespace" do
      #No namespace
      pi = @person.person_identifiers.new(value: "fec")
      expect(pi).not_to be_valid
    end
    it "should have case insensitive namespaces" do
      PersonIdentifier.create!(
        bioguideid: @person.bioguideid,
        namespace: "fec",
        value: "thesamevalue"
      )
      pi = PersonIdentifier.new(
            bioguideid: @person.bioguideid,
            namespace: "FEC",
            value: "thesamevalue"
          )
      expect(pi).not_to be_valid
    end
end