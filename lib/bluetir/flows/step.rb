# frozen_string_literal: true

module Bluetir
  module Flows
    # What every flow is handed: the browser and the things that describe the store.
    Context = Data.define(:browser, :storefront, :navigator, :assertions, :result, :screenshots)

    # Shared machinery for a flow: locating fields, navigating, and recording outcomes.
    class Step
      # A loading mask that outlasts this is a store in trouble, not a slow one.
      OVERLAY_TIMEOUT = 20

      def initialize(context)
        @context = context
      end

      private

      attr_reader :context

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

      def wait_for_overlay_to_clear
        return unless storefront.key?('loading_mask')

        locator = storefront['loading_mask'].locator
        wait_until?(timeout: OVERLAY_TIMEOUT) do
          browser.elements(locator).none?(&:present?)
        end
      end

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
