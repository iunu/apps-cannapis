namespace :notifier do
  task test: :environment do
    TaskRunner.simulate_failure
  end
end
