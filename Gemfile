source 'https://rubygems.org'

ruby '4.0.6'
gem 'rails', '~> 8.1.0'
gem 'sass-rails'
gem 'bootstrap-sass'
gem 'jquery-rails'
# JSON 3 removes positional options used by Rails' JSON decoder.
gem 'json', '~> 2.0'
gem 'bcrypt'
gem 'will_paginate'
gem 'aws-sdk-s3'
gem 'mini_magick'          
# Preserve the existing icon names until the browser/asset migration.
gem 'font-awesome-sass', '~> 5.15'
gem 'simple_form'
gem 'pg'
gem 'puma'
gem 'bootsnap'
# Match the existing Elasticsearch 7 service until search is migrated.
gem 'elasticsearch-model', '~> 7.0'
gem 'elasticsearch-rails', '~> 7.0'
gem 'elasticsearch', '~> 7.0'
gem 'truncato'
gem 'image_processing', '~> 1.2'

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console'
  gem 'listen', '~> 3.9'
end

group :development, :test do
  gem 'debug', require: false
  gem 'faker'
  gem 'rspec-rails', '~> 8.0'
end

group :test do
  # don't know if I need these, they came with rails install
  # gem 'minitest-reporters'
  # gem 'mini_backtrace'
  # gem 'guard-minitest'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'simplecov', :require => false
  gem 'capybara'
  gem 'launchy'
  gem 'shoulda-matchers'
end
