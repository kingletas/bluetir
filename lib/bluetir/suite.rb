# frozen_string_literal: true

module Bluetir
  # Runs the storefront checks and reports one tally for the whole run.
  class Suite
    # Mode to handler. A table rather than a case, so a mode with no
    # implementation is a fact the tests can check rather than a NoMethodError
    # somebody finds by running it — which is how three modes were once removed
    # by an edit and stayed green all the way to a live store.
    HANDLERS = {
      'order' => :place_an_order,
      'pages' => :sweep_pages,
      'probe' => :probe_selectors,
      'persona' => :shop_as_people,
      'baseline' => :capture_baseline,
      'acceptance' => :compare_with_baseline
    }.freeze

    MODES = HANDLERS.keys.freeze

    def initialize(configuration, mode: 'order', output: $stdout, seed: nil, baseline_out: nil)
      raise ConfigurationError, "unknown mode: #{mode}" unless MODES.include?(mode)

      @configuration = configuration
      @mode = mode
      @output = output
      @seed = seed || Random.new_seed
      @baseline_out = baseline_out
    end

    attr_reader :seed

    # Describes what a run would do, without opening a browser.
    def plan
      ["store:      #{@configuration.base_url}",
       "storefront: #{@configuration.storefront.summary}",
       "mode:       #{@mode}",
       "runs:       #{@configuration.runs}",
       "products:   #{Array(@configuration.orders['products']).size}",
       "assertions: #{assertions.summary}",
       "http:       #{@configuration.http.summary}"]
    end

    # Executes the run and returns the tally. Never raises for a failing check.
    def run
      @result = Result.new
      guard_assertions
      # Persona mode opens a browser per shopper, so it manages its own.
      if @mode == 'persona'
        execute(nil, 0)
      else
        session.open do |browser|
          context = build_context(browser, @result)
          @configuration.runs.times { |index| execute(context, index) }
        end
      end
      notify(@result)
      @result
    rescue RateLimited => e
      stopped_by(e)
    end

    # Not a failing store, and not something more runs will fix.
    def stopped_by(error)
      say "\n  STOPPED — #{error.message}"
      @result.fail('run', 'the store accepted the traffic', error.message)
      notify(@result)
      @result
    end

    private

    def assertions
      @assertions ||= PageAssertions.new(@configuration.assertions, screenshots: screenshots)
    end

    def screenshots
      @screenshots ||= Screenshots.new(@configuration.resolve(@configuration.screenshots_dir))
    end

    def session
      BrowserSession.new(base_url: @configuration.base_url, http: @configuration.http,
                         timeout: @configuration.timeout, headless: @configuration.headless)
    end

    def navigator_for(browser)
      url = Url.new(@configuration.base_url, params: @configuration.http.params)
      Navigator.new(browser, url: url, delay: @configuration.http.delay,
                             settle: @configuration.settle)
    end

    # An assertions file that asserts nothing would pass every run without checking anything.
    def guard_assertions
      return if @configuration.assertions.empty? || assertions.configured?

      raise ConfigurationError,
            'the assertions file defines no expectations, so it could never fail'
    end

    def build_context(browser, result)
      Flows::Context.new(browser: browser, storefront: @configuration.storefront,
                         navigator: navigator_for(browser), assertions: assertions,
                         result: result, screenshots: screenshots)
    end

    def execute(context, index)
      say "[run #{index + 1}/#{@configuration.runs}] #{@mode}"
      send(HANDLERS.fetch(@mode), context)
    end

    # Every persona shops the store from the front page to a checkout that is
    # ready to be placed. The order is never placed.
    # Every shopper gets their own browser.
    #
    # Clearing cookies between them is not the same thing and was worse: a
    # storefront hands the page a form key tied to the session it was rendered
    # for, so a cleared session mid-run makes the next add to cart fail in a way
    # that looks like a broken store. A new browser has no history to leak.
    def shop_as_people(_context)
      random = Random.new(@seed)
      shoppers = Shoppers.new(@configuration, @output)
      @configuration.personas.each do |persona|
        identity = persona.identity(random)
        session.open { |browser| shoppers.visit(build_context(browser, @result), persona, identity) }
      end
    end

    def probe_selectors(context)
      probe = Probe.new(context, @configuration.orders)
      probe.report(probe.run, @output, context.result)
    end

    def sweep_pages(context)
      assertions.sweep(context.browser, context.navigator, context.result)
    end

    def place_an_order(context)
      orders = @configuration.orders
      products = Array(orders['products'])
      if products.empty?
        return context.result.fail('cart', 'the order file lists products', 'none were listed')
      end

      products.each { |product| Flows::AddToCart.new(context).call(product) }
      Flows::ShippingQuote.new(context).call(orders.dig('customer', 'address'))
      Flows::Checkout.new(context).call(orders['customer'])
    end

    def capture_baseline(context)
      acceptance(context).capture(store: @configuration.base_url,
                                  to: @baseline_out || @configuration.baseline_file)
    end

    def compare_with_baseline(context)
      acceptance(context).compare(store: @configuration.base_url,
                                  against: @configuration.baseline_file)
    end

    def acceptance(context)
      Acceptance.new(context, @configuration.orders, @output)
    end

    def notify(result)
      notifier = Notifier.new(recipients: @configuration.recipients, sender: @configuration.sender,
                              server: @configuration.smtp_server)
      notifier.deliver(result, @configuration.base_url)
    end

    def say(message)
      @output.puts(message)
    end
  end
end
