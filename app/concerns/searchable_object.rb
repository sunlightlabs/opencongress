module SearchableObject
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
  end

  ELASTICSEARCH_SETTINGS = {
    index: { number_of_shards: 1 },
    analysis: {
      filter: {
        ngram: {
          type: 'nGram',
          min_gram:2,
          max_gram:15,
          token_chars: %w(letter digit punctuation symbol)
        }
      },
      analyzer: {
        default: {
          type: 'english'
        }
      }
    },
  }

  ELASTICSEARCH_MAPPINGS = {
    dynamic: 'true'
  }

  ELASTICSEARCH_INDEX_OPTIONS = {
    index_options: 'offsets',
    analyzer: 'english'
  }

  #========== METHODS

  #----- CLASS

  module ClassMethods

    # Drops the index from elasticsearch
    def drop_index
      self.__elasticsearch__.client.indices.delete index: self.index_name rescue nil
    end

    # Creates indexes (forcing overwrite by default of old index)
    # USE THIS TO REFRESH INDEX WITH NEW SETTINGS
    def create_index(force=true)
      self.__elasticsearch__.create_index! force: force
    end

    # Entry method for bulk importing of models for elasticsearch indexing.
    # USE THIS TO IMPORT DATA
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