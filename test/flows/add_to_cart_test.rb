# frozen_string_literal: true

require 'test_helper'

class AddToCartTest < Minitest::Test
  def setup
    @result = Bluetir::Result.new
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

  private

  def add(browser)
    context = Bluetir::Flows::Context.new(
      browser: browser, storefront: @storefront, navigator: navigator_for(browser),
      assertions: Bluetir::PageAssertions.new({}), result: @result, screenshots: nil
    )
    Bluetir::Flows::AddToCart.new(context)
  end
end
