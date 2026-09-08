# frozen_string_literal: true

require 'test_helper'

class CheckoutTest < Minitest::Test
  SUCCESS = 'Thank you for your purchase!'

  def setup
    @result = Bluetir::Report::Result.new
    @storefront = Bluetir::Storefront.new(YAML.safe_load(ConfigFixture.storefront))
    @order = YAML.safe_load(ConfigFixture.orders)['customer']
  end

  def test_it_places_an_order_when_every_step_works
    browser = FakeBrowser.new(text: SUCCESS)

    assert checkout(browser).call(@order)
    assert_predicate @result, :passed?
    assert_equal ['https://store.test/checkout/'], browser.visited
  end

  def test_it_fills_the_address_from_the_order
    browser = FakeBrowser.new(text: SUCCESS)
    checkout(browser).call(@order)

    assert_equal ['Test'], browser.text_field(name: 'firstname').set_values
    assert_equal ['United States'], browser.select_list(name: 'country_id').selected
  end

  def test_it_gives_each_run_a_different_email
    browser = FakeBrowser.new(text: SUCCESS)
    checkout(browser).call(@order)
    sent = browser.text_field(id: 'customer-email').set_values.first

    assert_match(/\Abuyer\+\d+@example\.test\z/, sent)
  end

  def test_it_clicks_place_order_exactly_once
    browser = FakeBrowser.new(text: SUCCESS)
    checkout(browser).call(@order)

    assert_equal 1, browser.button(css: '.payment-method._active button').clicks
  end

  def test_a_missing_confirmation_fails_the_run_without_raising
    browser = FakeBrowser.new(text: 'An error has occurred')

    refute checkout(browser).call(@order)
    refute_predicate @result, :passed?
    assert_match(/the order was placed/, @result.failure_lines.last)
  end

  def test_it_stops_before_paying_when_the_checkout_never_loads
    browser = FakeBrowser.new(text: SUCCESS, missing: [{ id: 'customer-email' }])

    refute checkout(browser).call(@order)
    assert_equal 0, browser.button(css: '.payment-method._active button').clicks
  end

  def test_an_address_field_the_profile_cannot_locate_does_not_stop_the_run
    browser = FakeBrowser.new(text: SUCCESS)
    order = @order.merge('address' => @order['address'].merge('wombat' => 'x'))

    assert_output(nil, /no selector for address field 'wombat'/) do
      assert checkout(browser).call(order)
    end
  end

  # Hyvä Checkout shows shipping and payment at once and has no button between
  # them. A profile that declares none must still reach the payment step.
  def test_it_reaches_payment_on_a_one_page_checkout
    without_continue = YAML.safe_load(ConfigFixture.storefront)
    without_continue['selectors'].delete('shipping_continue_button')
    @storefront = Bluetir::Storefront.new(without_continue)
    browser = FakeBrowser.new(text: SUCCESS)

    assert checkout(browser).call(order_for(address))
    assert_predicate @result, :passed?
  end

  # ScandiPWA keeps its place-order button disabled until the terms are agreed
  # to, and the control is a label wrapping a hidden input.
  def test_it_agrees_to_the_terms_when_the_profile_declares_a_control
    use_terms_control
    browser = FakeBrowser.new(text: SUCCESS)
    checkout(browser).review(@order)

    assert_equal 1, browser.element(css: 'label.tac').clicks
  end

  # Skipping a declared control because it is missing would tick a box beside an
  # agreement nobody made, and hide the real failure two steps downstream.
  def test_a_declared_terms_control_that_is_not_there_fails
    use_terms_control
    browser = FakeBrowser.new(text: SUCCESS, missing: [{ css: 'label.tac' }])

    refute checkout(browser).review(@order)
    assert_match(/terms/, @result.failure_lines.join)
  end

  # A store that keeps its cart in the browser bounces the checkout back to the
  # cart before the server has a quote. That is a race, and worth one more try.
  def test_it_tries_again_when_the_checkout_bounces_to_another_page
    browser = BouncingBrowser.new(text: SUCCESS, bounce_to: 'https://store.test/checkout/cart/')

    assert checkout(browser).review(@order)
    assert_predicate @result, :passed?
  end

  # A checkout that is merely slow is not retried: its timeout is the answer.
  def test_it_does_not_retry_a_checkout_that_simply_never_loads
    browser = FakeBrowser.new(text: SUCCESS, missing: [{ id: 'customer-email' }])

    refute checkout(browser).review(@order)
    checkout_visits = browser.visited.count { |u| u.include?('checkout') }

    assert_equal 1, checkout_visits
  end

  # A failure on the wrong page is the commonest confusion there is, and it is
  # indistinguishable from a slow page unless the url is in the message.
  def test_a_failure_says_which_page_it_happened_on
    browser = FakeBrowser.new(text: SUCCESS, missing: [{ id: 'customer-email' }])
    checkout(browser).review(@order)

    assert_match(%r{on https://store\.test/checkout/}, @result.failure_lines.join)
  end

  # A store without one must not be waited on for something it does not have.
  def test_a_profile_with_no_terms_control_still_finishes
    browser = FakeBrowser.new(text: SUCCESS)

    assert checkout(browser).review(@order)
  end

  private

  def use_terms_control
    with_terms = YAML.safe_load(ConfigFixture.storefront)
    with_terms['selectors']['terms_agreement'] = { 'type' => 'element', 'css' => 'label.tac' }
    @storefront = Bluetir::Storefront.new(with_terms)
  end

  def order_for(address)
    { 'email' => 'buyer@example.test', 'address' => address }
  end

  def address
    YAML.safe_load(ConfigFixture.orders)['customer']['address']
  end

  def checkout(browser)
    context = Bluetir::Flows::Context.new(
      browser: browser, storefront: @storefront, navigator: navigator_for(browser),
      assertions: Bluetir::Checks::PageAssertions.new({}), result: @result, screenshots: nil
    )
    Bluetir::Flows::Checkout.new(context)
  end
end
