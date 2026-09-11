# frozen_string_literal: true

require 'test_helper'

# Luma renders the billing address above Place Order after the button appears, so the click has to wait.
class PlaceOrderTest < Minitest::Test
  SUCCESS = 'Thank you for your purchase!'
  PLACE_ORDER = { css: '.payment-method._active button' }.freeze
  LOADER = { css: "div[data-role='loader']" }.freeze
  SETTLE = Bluetir::Flows::Step::STILL_FOR

  def setup
    @result = Bluetir::Report::Result.new
    @storefront = Bluetir::Storefront.new(YAML.safe_load(ConfigFixture.storefront))
    @order = YAML.safe_load(ConfigFixture.orders)['customer']
  end

  def test_it_waits_for_place_order_to_stop_moving_before_clicking
    browser = FakeBrowser.new(text: SUCCESS)
    button = place_order_button(browser, SlidingElement.new(PLACE_ORDER, moves_for: 0.3))

    assert checkout(browser, still_for: SETTLE).call(@order)
    assert_equal SlidingElement::RESTING_TOP, button.clicked_at
  end

  def test_it_clicks_place_order_again_while_something_else_takes_the_click
    browser = FakeBrowser.new(text: SUCCESS)
    button = place_order_button(browser, CoveredElement.new(PLACE_ORDER, covered_for: 2))

    assert checkout(browser).call(@order), "checkout failed: #{what_failed}"
    assert_predicate @result, :passed?
    assert_equal [3, 1], [button.attempts, button.clicks]
  end

  def test_a_place_order_button_that_stays_covered_fails_within_the_timeout
    browser = FakeBrowser.new(text: SUCCESS)
    button = place_order_button(browser, CoveredElement.new(PLACE_ORDER, covered_for: Float::INFINITY))

    with_default_timeout(1) { checkout(browser, still_for: SETTLE).call(@order) }

    assert_match(/the order was placed.*click intercepted.*billing-address-details/, what_failed)
    assert_equal 0, button.clicks
    assert_operator button.attempts, :>, 1
  end

  # Magento swaps the checkout step while the loader is being read, and Watir calls that a changing page.
  def test_a_page_changing_under_the_loading_mask_is_waited_out
    use_loading_mask
    browser = ChangingPageBrowser.new(changes: 2, text: SUCCESS, missing: [LOADER])

    assert checkout(browser).call(@order), "checkout failed: #{what_failed}"
    assert_predicate @result, :passed?
  end

  def test_a_page_that_never_stops_changing_under_the_loading_mask_fails
    use_loading_mask
    browser = ChangingPageBrowser.new(changes: 1_000, text: SUCCESS, missing: [LOADER])

    refute checkout(browser).call(@order)
    assert_match(/the checkout reached the payment step/, what_failed)
  end

  private

  def place_order_button(browser, element)
    browser.set_matches(:buttons, PLACE_ORDER, [element])
    element
  end

  def use_loading_mask
    with_mask = YAML.safe_load(ConfigFixture.storefront)
    with_mask['selectors']['loading_mask'] = { 'type' => 'element', 'css' => LOADER[:css] }
    @storefront = Bluetir::Storefront.new(with_mask)
  end

  def with_default_timeout(seconds)
    previous = Watir.default_timeout
    Watir.default_timeout = seconds
    yield
  ensure
    Watir.default_timeout = previous
  end

  def what_failed
    @result.failure_lines.join('; ')
  end

  def checkout(browser, still_for: 0)
    context = Bluetir::Flows::Context.new(
      browser: browser, storefront: @storefront, navigator: navigator_for(browser),
      assertions: Bluetir::Checks::PageAssertions.new({}), result: @result, screenshots: nil
    )
    Bluetir::Flows::Checkout.new(context, still_for: still_for)
  end
end
