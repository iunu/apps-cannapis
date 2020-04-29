# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

Dir[Rails.root.join('lib/apps-cannapis/**/*.rb')].sort.each { |f| require f }
