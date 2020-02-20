# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

if Gem.loaded_specs.key?('rubocop')
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop)
end
