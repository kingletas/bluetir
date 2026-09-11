# frozen_string_literal: true

module Bluetir
  module Flows
    # What every flow is handed: the browser and the things that describe the store.
    Context = Data.define(:browser, :storefront, :navigator, :assertions, :result, :screenshots)

    # Shared machinery for a flow: locating fields, navigating, and recording outcomes.
    class Step
      # A loading mask that outlasts this is a store in trouble, not a slow one.
      OVERLAY_TIMEOUT = 20

      # How long an element has to hold its position before a click is aimed at it, and how often it's read.
      STILL_FOR = 0.25
      STILL_POLL = 0.05

      # +still_for+ is how long a settled click waits for its target to hold still.
      def initialize(context, still_for: STILL_FOR)
        @context = context
        @still_for = still_for
      end

      private

      attr_reader :context, :still_for

      def browser = context.browser
      def storefront = context.storefront
      def result = context.result
      def assertions = context.assertions

      def field(name)
        Browser::Field.new(browser, storefront[name])
      end

      # Clicks, once the store has stopped covering the page.
      #
      # Magento drops a loading mask over the checkout while it talks to the
      # server, and a click that lands during it goes to the mask instead of the
      # button — Selenium calls that ElementClickIntercepted, and it is the
      # single commonest reason a Magento suite is flaky. A profile that names
      # its mask gets waited on.
      def click(field)
        wait_for_overlay_to_clear
        field.click
      end

      # Clicks once the page is uncovered and the element has stopped moving, and clicks again while
      # something else still takes the click. A refused click was never delivered, so this can't click twice.
      def click_once_settled(field, timeout: Watir.default_timeout)
        deadline = clock + timeout
        begin
          wait_for_overlay_to_clear
          wait_until_still(field, deadline)
          field.click
        rescue Selenium::WebDriver::Error::ElementClickInterceptedError
          raise if clock >= deadline

          retry
        end
      end

      def wait_for_overlay_to_clear
        return unless storefront.key?('loading_mask')

        locator = storefront['loading_mask'].locator
        wait_until?(timeout: OVERLAY_TIMEOUT) { overlay_gone?(locator) }
      end

      # A page that re-renders while the mask is being read hasn't finished, so it counts as still covered.
      def overlay_gone?(locator)
        browser.elements(locator).none?(&:present?)
      rescue Watir::Exception::LocatorException, Selenium::WebDriver::Error::StaleElementReferenceError
        false
      end

      # Waits until the element's box has held for still_for, or gives up at the deadline and lets the
      # click decide.
      def wait_until_still(field, deadline)
        box = field.box
        held_since = clock
        until clock >= deadline
          return if box && clock - held_since >= still_for

          sleep(STILL_POLL)
          reading = field.box
          next if reading == box

          box = reading
          held_since = clock
        end
      end

      def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      def optional_field(name)
        storefront.key?(name) ? field(name) : nil
      end

      def goto(path)
        context.navigator.go(path)
      end

      def url_for(path)
        context.navigator.url_for(path)
      end

      # Runs a check, records what happened, and never lets one failure end the run.
      #
      # Every failure carries the page it happened on. A store that redirects an
      # empty cart away from the checkout produces "the checkout page loaded"
      # failing on the cart page, and without the url that is indistinguishable
      # from a checkout that is merely slow.
      def expect(section, description)
        outcome = yield
        return result.pass(section, description) && outcome if outcome

        result.fail(section, description, "the condition was never true#{on_page}")
        outcome
      rescue Watir::Wait::TimeoutError
        record_failure(section, description, "it did not happen within #{Watir.default_timeout}s")
        false
      rescue StandardError => e
        record_failure(section, description, "#{e.class}: #{e.message}")
        false
      end

      def record_failure(section, description, reason)
        capture(section)
        result.fail(section, description, "#{reason}#{on_page}")
        nil
      end

      def on_page
        " (on #{browser.url})"
      rescue StandardError
        ''
      end

      def capture(section)
        context.screenshots&.capture(browser, "#{section}-failure")
      end

      # Whether the page shows this text, ignoring case for the reason in
      # Checks::PageAssertions: a theme's text-transform changes what the browser reports.
      def page_says?(text)
        browser.text.downcase.include?(text.to_s.downcase)
      end

      # Waits for a condition and answers whether it arrived, rather than raising.
      def wait_until?(timeout: Watir.default_timeout, &)
        browser.wait_until(timeout: timeout, &)
        true
      end
    end
  end
end
