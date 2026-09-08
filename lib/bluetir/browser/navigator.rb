# frozen_string_literal: true

module Bluetir
  module Browser
    # The one way the suite moves between pages, so the delay and the custom
    # parameters apply everywhere rather than wherever somebody remembered them.
    class Navigator
      # document.readyState is a STRING. Comparing it to a symbol is always false,
      # which turns this wait into a full timeout on every single page load.
      DOCUMENT_TIMEOUT = 10

      # What a store says when it wants us to stop. Every one of these is the
      # server refusing, not the storefront misbehaving.
      RATE_LIMITED = /too many requests|rate limit exceeded|\b429\b.{0,40}request/i

      def initialize(browser, url:, delay: 0.0, settle: 0.0)
        @browser = browser
        @url = url
        @delay = delay.to_f
        @settle = settle.to_f
        @moved = false
      end

      def base_url
        @url.base
      end

      def url_for(path)
        @url.for(path)
      end

      # Waits out the configured delay, loads the page, and lets it finish loading.
      def go(path)
        pause
        @browser.goto(url_for(path))
        settle
        refuse_to_continue if throttled?
      end

      private

      # Whether the store just told us to stop. Read from the page because a
      # WebDriver session cannot see the status code, and this phrase on a
      # storefront is a rate limit every time.
      def throttled?
        RATE_LIMITED.match?(@browser.text)
      rescue StandardError
        false
      end

      def refuse_to_continue
        raise RateLimited,
              "#{@browser.url} answered with a rate limit. Nothing after this " \
              'would say anything about the store, so the run stops here. Raise ' \
              'http.delay and come back later.'
      end

      # A store built in JavaScript is not finished when the document is. Alpine
      # has not bound the add-to-cart button yet, and a click that lands before it
      # does silently does nothing — which then looks like an empty cart three
      # pages later. The document wait is free; the extra settle is per store.
      def settle
        @browser.wait_until(timeout: DOCUMENT_TIMEOUT) { @browser.ready_state.to_s == 'complete' }
        sleep(@settle) if @settle.positive?
      rescue StandardError
        nil
      end

      # The first page load has nothing to be polite about; every later one does.
      def pause
        sleep(@delay) if @moved && @delay.positive?
        @moved = true
      end
    end
  end
end
