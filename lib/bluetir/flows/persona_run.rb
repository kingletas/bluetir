# frozen_string_literal: true

require_relative 'step'

module Bluetir
  module Flows
    # One shopper's whole visit, from landing to the order being ready to place.
    #
    # This is the acceptance test: it proves a real person could get from the
    # front page to a completed checkout. It deliberately stops at the last
    # button, so it can be run against a store nobody wants orders on.
    class PersonaRun < Step
      def initialize(context, persona:, identity:, orders:)
        super(context)
        @persona = persona
        @identity = identity
        @orders = orders
      end

      # Returns whether this shopper reached a checkout ready to be placed.
      def call
        resize
        land
        browse if @persona.browses
        search if @persona.searches
        return false unless filled_the_cart?

        ShippingQuote.new(context).call(address)
        Checkout.new(context).review(order)
      end

      private

      def resize
        return if @persona.viewport.empty?

        browser.window.resize_to(*@persona.viewport)
      rescue StandardError => e
        warn "[warn] could not size the window for #{@persona.name}: #{e.message}"
      end

      def land
        goto('')
        assertions.verify(browser, 'home', result)
      end

      # A category page is where most people actually start, and a store that
      # renders one wrongly loses the sale before any of the checkout matters.
      def browse
        path = storefront.paths['category']
        return unless path

        goto(path)
        assertions.verify(browser, 'category', result)
      end

      def search
        path = storefront.paths['search']
        return unless path

        goto(path)
        assertions.verify(browser, 'search', result)
      end

      # Buys as many distinct products as this persona shops for, cycling the
      # catalogue when it is shorter than their basket.
      def filled_the_cart?
        catalogue = Array(@orders['products'])
        return false if catalogue.empty?

        wanted = Array.new(@persona.products) { |i| catalogue[i % catalogue.size] }
        wanted.map { |product| AddToCart.new(context).call(product) }.any?
      end

      def address
        {
          'firstname' => @identity.firstname, 'lastname' => @identity.lastname,
          'street' => @identity.street, 'city' => @identity.city,
          'region' => @identity.region, 'postcode' => @identity.postcode,
          'country' => @identity.country, 'telephone' => @identity.telephone
        }
      end

      def order
        { 'email' => @identity.email, 'address' => address }
      end
    end
  end
end
