# configuration options for elasticsearch
CONFIG = {
  host: Settings.elasticsearch_host || 'http://localhost:9200/',
  retry_on_failure: true,
  transport_options: {
    request: {
      timeout: nil,
      open_timeout: nil
    }
  },
}

# load additional configuration settings from yml file if it exists.
if File.exists?('config/elasticsearch.yml')
  CONFIG.merge!(YAML.load_file('config/elasticsearch.yml').symbolize_keys)
end

# configure elasticsearch client for all models with settings defined above
Elasticsearch::Model.client = Elasticsearch::Client.new(CONFIG)
