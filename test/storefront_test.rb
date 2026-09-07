# frozen_string_literal: true

require 'test_helper'

class StorefrontTest < Minitest::Test
  def setup
    @storefront = Bluetir::Storefront.new(
      'name' => 'Test store',
      'paths' => { 'cart' => 'checkout/cart/' },
      'texts' => { 'order_success' => 'Thank you' },
      'selectors' => { 'add_to_cart_button' => { 'type' => 'button', 'id' => 'go' } }
    )
  end

  def test_it_hands_back_a_declared_selector
    assert_equal 'button', @storefront['add_to_cart_button'].type
  end

  def test_a_missing_selector_names_the_profile_and_the_selector
    error = assert_raises(Bluetir::MissingSelectorError) { @storefront['place_order_button'] }

    assert_match(/Test store/, error.message)
    assert_match(/place_order_button/, error.message)
  end

  def test_a_missing_path_is_a_configuration_error
    assert_raises(Bluetir::ConfigurationError) { @storefront.path('checkout') }
  end

  def test_a_missing_text_is_a_configuration_error
    assert_raises(Bluetir::ConfigurationError) { @storefront.text('add_to_cart_confirmation') }
  end

  def test_it_reports_which_selectors_it_has
    assert_equal ['add_to_cart_button'], @storefront.selector_names
    assert @storefront.key?('add_to_cart_button')
    refute @storefront.key?('quantity_field')
  end
end
