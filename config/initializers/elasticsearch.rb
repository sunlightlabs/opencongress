# Configuration options for elasticsearch
CONFIG = {
  host: Settings.elasticsearch_host || 'http://localhost:9200/',
  retry_on_failure: true,
  transport_options: {
    request: {
      timeout: 360000,
      open_timeout: 360000
    }
  },
}

# load additional configuration settings from yml file if it exists.
if File.exists?('config/elasticsearch.yml')
  CONFIG.merge!(YAML.load_file('config/elasticsearch.yml').symbolize_keys)
end

# configure elasticsearch client for all models with settings defined above
Elasticsearch::Model.client = Elasticsearch::Client.new(CONFIG)

# USEFUL LINKS
#
# http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/setup-dir-layout.html
# http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/setup-configuration.html

# USEFUL COMMANDS
#
# Monitor state of indices
#   FORMAT: curl '<host>:<port>/_cat/indices?v'
#   COPY-AND-PASTE: curl 'http://localhost:9200/_cat/indices?v'
#
# See all settings for elasticsearch as JSON
#   COPY-AND-PASTE: curl "localhost:9200/_nodes?pretty=true&settings=true"