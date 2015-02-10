module SearchableObject
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
  end

  #========== CONSTANTS

  # All constants below starting with ELASTICSEARCH are default options.

  # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/analysis.html
  ELASTICSEARCH_SETTINGS = {
    index: { number_of_shards: 1 },
    analysis: {
      filter: {
        edge_ngram: {
          type: 'edge_ngram',
          min_gram:2,
          max_gram:20,
          token_chars: %w(letter digit punctuation symbol)
        }
      },
      analyzer: {
        edge_ngram: {
          type: 'custom',
          tokenizer: 'standard',
          filter: %w(standard edge_ngram)
        }
      }
    },
  }

  # http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/mapping.html
  ELASTICSEARCH_MAPPINGS = {
    dynamic: 'true'
  }

  ELASTICSEARCH_INDEX_OPTIONS = {
    index_options: 'offsets',
    analyzer: 'edge_ngram'
  }

  ELASTICSEARCH_BOOSTS = {
    extreme: 1000000,
    high: 100000,
    medium: 10000,
    low: 1000,
    small: 100,
    tiny: 10
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