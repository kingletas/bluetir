# frozen_string_literal: true

require 'watir'

module Bluetir
  module Browser
    # Owns the browser for the length of a run, and closes it whatever happens.
    class Session
      def initialize(base_url:, http:, timeout: 30, headless: true, browser: :chrome)
        @base_url = base_url
        @http = http
        @timeout = timeout
        @headless = headless
        @browser_name = browser
      end

      # Opens a browser, applies the HTTP settings, yields it, and always closes it.
      def open
        Watir.default_timeout = @timeout
        browser = start
        begin
          apply_headers(browser)
          apply_origin_state(browser)
          yield browser
        ensure
          close(browser)
        end
      end

      private

      def start
        args = %w[--headless=new --window-size=1440,900]
        args.shift unless @headless
        args << "--user-agent=#{@http.user_agent}"
        Watir::Browser.new(@browser_name, options: { args: args })
      end

      # Extra request headers are a CDP capability rather than a WebDriver one, so
      # a browser that does not speak CDP gets a warning instead of a crash.
      def apply_headers(browser)
        return unless @http.headers?

        browser.driver.execute_cdp('Network.enable')
        browser.driver.execute_cdp('Network.setExtraHTTPHeaders', 'headers' => @http.headers)
      rescue StandardError => e
        warn "[warn] could not set custom headers: #{e.message}"
      end

      # Cookies and localStorage both belong to an origin, so neither can be set
      # until the browser is on one. This loads the store's front page once and
      # throws that page away.
      def apply_origin_state(browser)
        return unless @http.cookies? || @http.local_storage?

        browser.goto(@base_url)
        apply_cookies(browser)
        apply_local_storage(browser)
      rescue StandardError => e
        warn "[warn] could not prepare the origin: #{e.message}"
      end

      def apply_cookies(browser)
        @http.cookies.each do |cookie|
          browser.cookies.add(cookie[:name], cookie[:value], **rest(cookie))
        end
      end

      # Where a storefront keeps state a cookie cannot reach. ScandiPWA records a
      # dismissed cookie notice here, and seeding it means the notice never opens
      # — so nothing has to click a banner to get it out of the way.
      def apply_local_storage(browser)
        @http.local_storage.each do |key, value|
          browser.execute_script('window.localStorage.setItem(arguments[0], arguments[1]);',
                                 key, value)
        end
      end

      def rest(cookie)
        cookie.except(:name, :value)
      end

      def close(browser)
        browser.close
      rescue StandardError => e
        warn "[warn] the browser did not close cleanly: #{e.message}"
      end
    end
  end
end
