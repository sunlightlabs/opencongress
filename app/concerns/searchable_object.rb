module SearchableObject
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
  end

  #========== METHODS

  #----- CLASS

  module ClassMethods

    # Entry method for bulk importing of models for elasticsearch indexing.
    def import_bulk
      self.includes(self::SERIALIZATION_STYLES[:elasticsearch][:include]).find_in_batches do |record|
        bulk_index(record)
      end
    end

    # Prepares each individual record for indexing
    def prepare_records(records)
      records.map {|record| { index: { _id: record.id, data: record.as_indexed_json } } }
    end

    # Handles the actual bulk indexing
    def bulk_index(records)
      self.__elasticsearch__.client.bulk({
        index: self.__elasticsearch__.index_name,
        type: self.__elasticsearch__.document_type,
        body: prepare_records(records)
      })
    end

  end

  def self.abstract_class?
    true
  end

  #----- INSTANCE

end