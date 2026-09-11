# config/initializers/elasticsearch.rb

if Rails.env.development? || Rails.env.test?
  default_url = Rails.env.test? ? 'http://localhost:9250' : 'http://localhost:9200'
  Elasticsearch::Model.client = Elasticsearch::Client.new(
    url: ENV.fetch('ELASTICSEARCH_URL', default_url)
  )
end
