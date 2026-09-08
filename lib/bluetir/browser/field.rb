# frozen_string_literal: true

module Bluetir
  module Browser
    # One element on the page, and the few things a flow ever does to it.
    class Field
      TOGGLES = %w[radio checkbox].freeze

      def initialize(browser, selector)
        @browser = browser
        @selector = selector
      end

      def element
        @selector.on(@browser)
      end

      # The first match that a customer could actually use.
      #
      # One selector often matches several things — a storefront listing three
      # delivery options under one class is the case that found this. Watir hands
      # back the first, and on ScandiPWA the first is a free-shipping option the
      # cart does not qualify for and which is permanently disabled. Clicking it
      # waits out the full timeout for a button the store is refusing to offer.
      #
      # Falls back to the first match so an unusable element still fails with the
      # message it would have had.
      def usable
        @selector.all_on(@browser).find { |candidate| available?(candidate) } || element
      rescue StandardError
        element
      end

      def toggle?
        TOGGLES.include?(@selector.type)
      end

      def present?
        element.present?
      rescue Watir::Exception::UnknownObjectException
        false
      end

      # Sets a value the way this kind of element expects to receive one.
      def fill(value)
        return choose if toggle?

        @selector.type == 'select_list' ? element.select(value.to_s) : element.set(value.to_s)
      end

      # Picks this option. A radio or a checkbox is set; anything else is clicked,
      # because a storefront built in React often renders a choice as a button
      # rather than as an input.
      def choose
        return click unless toggle?

        usable.set
        self
      end

      # Clicks once the element is actually on the page, and only once it is
      # somewhere a click can land.
      #
      # Scrolling first is not cosmetic. A storefront with a sticky footer — every
      # one of them, on a phone — leaves the bottom of the viewport covered, and a
      # click aimed at whatever is under it goes to the footer. Selenium calls
      # that ElementClickIntercepted, and it only ever happens at the widths
      # nobody tests by hand.
      def click
        target = usable
        target.wait_until(&:present?)
        into_view(target)
        target.click
        self
      end

      def to_s
        @selector.to_s
      end

      private

      # Best effort: a browser that cannot scroll to an element can still click it,
      # and failing the run over the attempt would be worse than the interception.
      def into_view(target)
        target.scroll.to(:center)
      rescue StandardError
        nil
      end

      # A div has no notion of being enabled, so only an element that answers the
      # question is judged on it.
      def available?(candidate)
        return false unless candidate.present?

        begin
          candidate.enabled?
        rescue StandardError
          true
        end
      end
    end
  end
end
