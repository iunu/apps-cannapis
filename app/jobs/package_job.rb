class PackageJob < ApplicationJob
  queue_as :default
  WAIT_TIME = 5.minutes

  def perform(func)
    method(func).call
  end

  def wait_and_perform_in(func)
    set(self.WAIT_TIME).perform_later(func)
  end
end
