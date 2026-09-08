# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'pathname'
require 'bluetir'

# A stand-in for a Watir element that records what was done to it.
class FakeElement
  attr_reader :locator, :set_values, :selected, :clicks

  def initialize(locator, present: true, enabled: true)
    @locator = locator
    @present = present
    @enabled = enabled
    @set_values = []
    @selected = []
    @clicks = 0
  end

  def present? = @present

  # An acceptance run checks the place-order button is usable without clicking
  # it, and a disabled option has to be distinguishable from a missing one.
  def enabled? = @present && @enabled
  def set(value = nil) = @set_values << value
  def select(value) = @selected << value
  def click = @clicks += 1

  # Watir scrolls an element into view before clicking it, so the double has to
  # offer the same shape or every click raises.
  def scroll = self
  def to(_position) = self

  def wait_until(timeout: nil)
    raise Watir::Wait::TimeoutError, "never became true (#{timeout})" unless yield(self)

    self
  end
end

# A stand-in for a Watir browser. Every element it hands out is remembered by locator.
class FakeBrowser
  attr_reader :visited, :elements, :url, :wait_failures, :scripts
  attr_accessor :text

  def initialize(text: '', missing: [])
    @text = text
    @missing = missing
    @visited = []
    @elements = {}
    @collections = {}
    @url = 'about:blank'
    @wait_failures = 0
    @scripts = []
  end

  # Watir returns a String here, not a Symbol. The double has to match, or a
  # comparison against the wrong type looks fine in the tests and stalls for a
  # full timeout against a real browser.
  def ready_state = 'complete'

  # The baseline records page titles, so a double without one makes every page
  # look like a failure to load.
  def title = 'Fake page'

  def goto(url)
    @visited << url
    @url = url
  end

  %i[element button link text_field textarea select_list radio checkbox div span].each do |kind|
    define_method(kind) do |locator|
      key = [kind, locator]
      preset = @collections[[plural(kind), locator]]
      next preset.first if preset&.any?

      @elements[key] ||= FakeElement.new(locator, present: !@missing.include?(locator))
    end
  end

  # The collection side. A selector that matches several elements is the whole
  # reason Browser::Field looks past the first one.
  %i[elements buttons links text_fields textareas select_lists radios checkboxes
     divs spans].each do |kind|
    define_method(kind) do |locator|
      @collections[[kind, locator]] ||= [send(singular(kind), locator)]
    end
  end

  def set_matches(kind, locator, elements)
    @collections[[kind, locator]] = elements
  end

  def matches(kind, locator)
    @collections[[kind, locator]]
  end

  def plural(kind)
    kind == :checkbox ? :checkboxes : :"#{kind}s"
  end

  def singular(kind)
    kind == :checkboxes ? :checkbox : kind.to_s.sub(/s\z/, '').to_sym
  end

  def wait_until(timeout: nil)
    unless yield(self)
      @wait_failures += 1
      raise Watir::Wait::TimeoutError, "never became true (#{timeout})"
    end
    self
  end

  # The persona runner clears the session between shoppers, so the double has to
  # record that rather than blow up.
  def cookies = @cookies ||= FakeCookies.new

  def execute_script(script, *args)
    @scripts << [script, args]
    nil
  end

  def refresh = self

  def screenshot = self
  def save(_path) = self
  def close = self
end

# A real Browser::Navigator over a fake browser, with the delay turned off for the tests.
def navigator_for(browser, base = 'https://store.test', params: {})
  Bluetir::Browser::Navigator.new(browser, url: Bluetir::Browser::Url.new(base, params: params), delay: 0)
end

# Records what was done to the cookie jar.
class FakeCookies
  attr_reader :clears, :added

  def initialize
    @clears = 0
    @added = []
  end

  def clear = @clears += 1
  def add(name, value, **rest) = @added << [name, value, rest]
end

# A browser that bounces the first checkout it is sent to, the way a storefront
# does when the server has no quote yet, and behaves on the second attempt.
class BouncingBrowser < FakeBrowser
  def initialize(bounce_to:, **rest)
    super(**rest)
    @bounce_to = bounce_to
    @bounced = false
  end

  def goto(url)
    if url.include?('checkout/') && !@bounced
      @bounced = true
      return super(@bounce_to)
    end
    super
  end
end

# Builds a temporary config tree so Configuration can be exercised against real files.
module ConfigFixture
  module_function

  def write(dir, files)
    files.each do |name, contents|
      path = Pathname.new(dir).join(name)
      path.dirname.mkpath
      path.write(contents)
    end
    Pathname.new(dir).join('bluetir.yml')
  end

  def storefront
    <<~YML
      name: Test store
      platform: magento2
      paths:
        cart: checkout/cart/
        checkout: checkout/
        category: a-category.html
        search: catalogsearch/result/?q=thing
      texts:
        add_to_cart_confirmation: "to your shopping cart"
        order_success: "Thank you for your purchase!"
      selectors:
        add_to_cart_button:       { type: button,      id: product-addtocart-button }
        quantity_field:           { type: text_field,  id: qty }
        add_to_cart_confirmation: { type: div,         css: "div.message-success" }
        checkout_email:           { type: text_field,  id: customer-email }
        address_firstname:        { type: text_field,  name: firstname }
        address_country:          { type: select_list, name: country_id }
        shipping_method:          { type: radio,       css: "input[value='flatrate_flatrate']" }
        shipping_continue_button: { type: button,      css: "button[data-role='opc-continue']" }
        payment_method:           { type: radio,       id: checkmo }
        place_order_button:       { type: button,      css: ".payment-method._active button" }
    YML
  end

  def config(extra = '')
    <<~YML
      base_url: https://store.test/
      storefront: storefronts/test.yml
      orders: orders/test.yml
      #{extra}
    YML
  end

  def orders
    <<~YML
      products:
        - url: "a-product.html"
          qty: 2
      customer:
        email: "buyer@example.test"
        address:
          firstname: "Test"
          country: "United States"
    YML
  end
end
