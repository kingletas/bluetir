# frozen_string_literal: true

require 'test_helper'

class AddToCartTest < Minitest::Test
  SIZE = { 'type' => 'select_list', 'css' => '.size select', 'select' => 'M' }.freeze
  SWATCH = { 'type' => 'div', 'css' => ".swatch-option[data-option-label='Purple']" }.freeze
  ADD_BUTTON = { id: 'product-addtocart-button' }.freeze

  def setup
    @result = Bluetir::Report::Result.new
    @storefront = Bluetir::Storefront.new(YAML.safe_load(ConfigFixture.storefront))
    @product = { 'url' => 'a-product.html', 'qty' => 2 }
  end

  def test_it_confirms_from_the_message_when_the_store_shows_one
    browser = FakeBrowser.new(text: 'anything')

    assert add(browser).call(@product)
    assert_predicate @result, :passed?
  end

  # Hyvä intercepts the form with Alpine and shows a message — unless Alpine has
  # not bound it yet, in which case the browser submits the form and navigates
  # away. That is still an add, and the cart is where the evidence is.
  def test_it_confirms_at_the_cart_when_the_add_navigated_away
    browser = FakeBrowser.new(text: 'A Product — one item', missing: [{ css: 'div.message-success' }])

    assert add(browser).call(@product)
    assert_includes browser.visited.last, 'checkout/cart/'
  end

  def test_an_add_that_neither_confirms_nor_reaches_the_cart_fails
    browser = FakeBrowser.new(text: 'an error page', missing: [{ css: 'div.message-success' }])

    refute add(browser).call(@product)
    assert_match(/added a-product.html to the cart/, @result.failure_lines.join)
  end

  def test_each_option_is_chosen_before_the_add
    browser = FakeBrowser.new(text: 'anything')

    assert add(browser).call(with_options)
    assert_equal ['M'], browser.select_list(css: '.size select').selected
    assert_equal 1, browser.div(css: SWATCH['css']).clicks
  end

  def test_each_option_chosen_is_recorded_as_a_check
    add(FakeBrowser.new(text: 'anything')).call(with_options)

    assert_equal 3, @result.passed
    assert_match(/chose option 2 \(div .*\) on a-product.html/, @result.checks[1].description)
  end

  def test_a_product_without_options_records_no_option_check
    add(FakeBrowser.new(text: 'anything')).call(@product)

    assert_equal ['added a-product.html to the cart'], @result.checks.map(&:description)
  end

  def test_an_option_the_page_refuses_fails_the_add_instead_of_raising
    browser = refusing_the_size(FakeBrowser.new(text: 'anything'))

    refute add(browser).call(with_options)
    assert_match(/cart: chose option 1 .*NoValueFoundException: "M" not found/, @result.failure_lines.join)
    assert_equal 0, browser.button(ADD_BUTTON).clicks
  end

  def test_it_stops_at_the_first_option_the_page_refuses
    browser = refusing_the_size(FakeBrowser.new(text: 'anything'))
    add(browser).call(with_options)

    assert_equal 0, browser.div(css: SWATCH['css']).clicks
    assert_equal 1, @result.failed
  end

  def test_an_option_missing_from_the_page_fails_the_add
    browser = FakeBrowser.new(text: 'anything', missing: [{ css: SWATCH['css'] }])

    refute add(browser).call(@product.merge('options' => [SWATCH]))
    assert_match(/chose option 1 .* did not happen within/, @result.failure_lines.join)
    assert_equal 0, browser.button(ADD_BUTTON).clicks
  end

  private

  def with_options
    @product.merge('options' => [SIZE, SWATCH])
  end

  # The live failure: a drop-down selector on a store whose options are swatches.
  def refusing_the_size(browser)
    browser.select_list(css: '.size select').define_singleton_method(:select) do |value|
      raise Watir::Exception::NoValueFoundException, "#{value.inspect} not found"
    end
    browser
  end

  def add(browser)
    context = Bluetir::Flows::Context.new(
      browser: browser, storefront: @storefront, navigator: navigator_for(browser),
      assertions: Bluetir::Checks::PageAssertions.new({}), result: @result, screenshots: nil
    )
    Bluetir::Flows::AddToCart.new(context)
  end
end
