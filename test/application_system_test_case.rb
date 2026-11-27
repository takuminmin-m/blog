require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end

# Capybara's Chrome reset ends by clearing storage for origin "*", which Chrome 158 rejects
# ("* is not a valid URL"), so every system test's teardown errors. Skip only that call: the reset
# still clears cookies before it, and the app keeps nothing in localStorage or sessionStorage.
module SkipWildcardStorageClear
  def execute_cdp(cmd, params = {})
    return if cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(SkipWildcardStorageClear)
