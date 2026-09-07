# frozen_string_literal: true

require_relative 'step'

module Bluetir
  module Flows
    # Asks the cart page for a shipping quote, where the store offers one.
    #
    # Magento 2 can estimate shipping in the cart or leave it to the checkout page.
    # A profile that declares no estimate selectors skips this flow entirely, which
    # is a supported storefront rather than a failure.
    class ShippingQuote < Step
      ESTIMATE_FIELDS = %w[country region postcode].freeze

      # Returns whether an estimate was actually requested.
      def call(destination)
        goto(storefront.path('cart'))
        assertions.verify(browser, 'cart', result)
        return false unless offers_estimate?

        open_estimator
        # Declared but not rendered is a gap, not a quote. Reporting it as a
        # pass would put a tick beside something that never happened.
        unless estimator_on_page?
          warn '[info] the cart shows no shipping estimator, so no quote was requested'
          return false
        end

        expect('cart', 'the cart returned a shipping quote') do
          fill_destination(destination)
          request_quote
          choose_method
        end
      end

      private

      def offers_estimate?
        ESTIMATE_FIELDS.any? { |name| storefront.key?("estimate_#{name}") }
      end

      # Luma keeps the estimator collapsed, and its fields are not in the page
      # until it is opened. A profile that names the toggle gets it clicked.
      def open_estimator
        toggle = optional_field('estimate_toggle')
        return unless toggle&.present?

        click(toggle)
        wait_until?(timeout: 5) { estimator_on_page? }
      rescue StandardError => e
        warn "[warn] could not open the shipping estimator: #{e.message}"
      end

      def estimator_on_page?
        ESTIMATE_FIELDS.any? { |name| optional_field("estimate_#{name}")&.present? }
      end

      def fill_destination(destination)
        ESTIMATE_FIELDS.each do |name|
          value = destination&.[](name)
          target = optional_field("estimate_#{name}")
          target.fill(value) if value && target&.present?
        end
      end

      def request_quote
        button = optional_field('estimate_button')
        click(button) if button&.present?
      end

      def choose_method
        method = optional_field('cart_shipping_method')
        return true unless method
        return false unless wait_until? { method.present? }

        method.choose
      end
    end
  end
end
