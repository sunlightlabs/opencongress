module SearchableObject
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
  end

  ELASTICSEARCH_SETTINGS = {
    index: { number_of_shards: 1 },
    analysis: {
      analyzer: {
        autocomplete: {
          type: 'custom',
          tokenizer:'standard',
          filter: %w(standard lowercase stop kstem ngram)
        }
      },
      filter: {
        ngram: {
          type: 'ngram',
          min_gram:2,
          max_gram:15
        }
      }
    },
  }

  ELASTICSEARCH_MAPPINGS = {
    dynamic: 'false',
    index_options: 'offsets'
  }

  #========== METHODS

  #----- CLASS

  module ClassMethods

    # Entry method for bulk importing of models for elasticsearch indexing.
    def import_bulk
      self.includes(self::SERIALIZATION_STYLES[:elasticsearch][:include]).find_in_batches do |record|
        bulk_index(record)
      end
    end

    # Handles the actual bulk indexing
    def bulk_index(records)
      self.__elasticsearch__.client.bulk({
        index: self.__elasticsearch__.index_name,
        type: self.__elasticsearch__.document_type,
        body: prepare_records(records)
      })
    end

    # Prepares each individual record for indexing
    def prepare_records(records)
      records.map {|record| { index: { _id: record.id, data: record.as_indexed_json } } }
    end

  end

  def self.abstract_class?
    true
  end

  #----- INSTANCE

end