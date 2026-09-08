# frozen_string_literal: true

module Bluetir
  module Checks
    # Reports which of a storefront profile's selectors actually resolve, and where.
    #
    # This is how a profile for a new theme gets built. Writing selectors from a
    # theme's documentation and finding out during a checkout which of them were
    # wrong is the slow way round; this loads each page once and says.
    #
    # It never places an order. It adds one product to the cart, because a cart
    # page with nothing in it and a checkout that redirects away from itself
    # cannot tell you whether their selectors are right.
    class Probe
      Sighting = Data.define(:name, :pages, :unreached_stage)
      Landing = Data.define(:label, :asked, :got)

      # The stages this probe actually drives to.
      VISITED_STAGES = %w[home product after-add cart checkout].freeze

      def initialize(context, orders)
        @context = context
        @orders = orders
        @pages = {}
        @titles = {}
        @landings = []
      end

      # Where each page actually ended up. A store that redirects an empty cart
      # away from the checkout is the commonest reason a probe finds nothing, and
      # it is invisible unless somebody writes down where the browser landed.
      attr_reader :landings, :titles

      # Visits each page and records where every selector was found.
      def run
        visit('home', '')
        visit('product', first_product_url)
        fill_the_cart
        record('after-add')
        visit('cart', path('cart'))
        visit('checkout', path('checkout'))
        sightings
      end

      # Prints where each page landed and where each selector resolved, and
      # records the outcome. A page that answered from somewhere else was not the
      # page being probed, and a selector found nowhere is a broken profile.
      def report(sightings, output, result)
        @landings.each { |landing| report_landing(landing, output, result) }
        output.puts
        sightings.each { |sighting| report_sighting(sighting, output, result) }
      end

      # Selectors the profile declares that were found on no page at all.
      def unseen(sightings)
        sightings.reject { |s| s.pages.any? }
      end

      private

      def report_landing(landing, output, result)
        moved = strip_query(landing.got) != strip_query(landing.asked)
        output.puts format('  %<label>-10s %<got>s%<note>s', label: landing.label,
                                                             got: landing.got,
                                                             note: moved ? '   <- REDIRECTED' : '')
        return unless moved

        result.fail('probe', "#{landing.label} page loads",
                    "asked for #{landing.asked} and landed on #{landing.got}")
      end

      # A trailing slash on the store root is not a redirect. Asking for
      # https://shop.test and landing on https://shop.test/ is the same page, and
      # reporting it trains you to ignore the column that reports a real one.
      def strip_query(url)
        url.to_s.sub(/[?#].*\z/, '').sub(%r{/+\z}, '')
      end

      def report_sighting(sighting, output, result)
        output.puts format('  %<name>-26s %<where>s', name: sighting.name,
                                                      where: describe_sighting(sighting))
        description = "#{sighting.name} resolves"
        return result.pass('probe', description) if sighting.pages.any?
        return if sighting.unreached_stage

        result.fail('probe', description, 'found on no page the probe visited')
      end

      def describe_sighting(sighting)
        return sighting.pages.join(', ') if sighting.pages.any?
        return "not visited (stage: #{sighting.unreached_stage})" if sighting.unreached_stage

        'NOT FOUND'
      end

      def storefront
        @context.storefront
      end

      def browser
        @context.browser
      end

      def path(name)
        storefront.paths[name]
      end

      def first_product_url
        Array(@orders['products']).first&.fetch('url', nil)
      end

      # Adding to the cart is what makes the cart and checkout pages real. The
      # order is never placed, so nothing here commits anything.
      def fill_the_cart
        product = Array(@orders['products']).first
        return unless product

        Flows::AddToCart.new(@context).call(product)
      rescue StandardError => e
        warn "[warn] could not fill the cart, so cart and checkout may look empty: #{e.message}"
      end

      def visit(label, url)
        return if url.nil?

        # The navigator already waits for the document and for the store's own
        # configured settle, so there is nothing to add here. A second pause
        # would just be a knob that has to agree with the first one.
        @context.navigator.go(url)
        note_landing(label, url)
        record(label)
      rescue StandardError => e
        warn "[warn] #{label} page did not load: #{e.message}"
        @pages[label] = []
      end

      def note_landing(label, url)
        @landings << Landing.new(label: label, asked: @context.navigator.url_for(url),
                                 got: browser.url)
        @titles[label] = browser.title.to_s
      end

      # A confirmation message is gone by the next page load, so what is on screen
      # right after the add has to be counted there and then.
      def record(label)
        @pages[label] = found_here
      end

      def found_here
        storefront.selector_names.select { |name| resolves?(name) }
      end

      def resolves?(name)
        Browser::Field.new(browser, storefront[name]).present?
      rescue StandardError
        false
      end

      def sightings
        storefront.selector_names.map do |name|
          seen = @pages.select { |_, found| found.include?(name) }.keys
          Sighting.new(name: name, pages: seen, unreached_stage: unreached(name, seen))
        end
      end

      # A selector that names a stage this probe never drives to is not missing,
      # and calling it missing would train you to ignore the column.
      def unreached(name, seen)
        stage = storefront.stage_of(name)
        return nil if seen.any? || stage.nil? || VISITED_STAGES.include?(stage)

        stage
      end
    end
  end
end
