# frozen_string_literal: true

require 'test_helper'

class FieldTest < Minitest::Test
  def setup
    @browser = FakeBrowser.new
  end

  def test_it_sets_a_text_field
    field('type' => 'text_field', 'name' => 'city').fill('Austin')

    assert_equal ['Austin'], @browser.text_field(name: 'city').set_values
  end

  def test_it_selects_from_a_list
    field('type' => 'select_list', 'name' => 'country_id').fill('United States')

    assert_equal ['United States'], @browser.select_list(name: 'country_id').selected
  end

  def test_choosing_a_radio_sets_it
    field('type' => 'radio', 'id' => 'flat').choose

    assert_equal [nil], @browser.radio(id: 'flat').set_values
  end

  # ScandiPWA renders a delivery option as a button rather than an input, so
  # choosing one has to be a click or the profile cannot express it at all.
  def test_choosing_a_button_clicks_it
    field('type' => 'button', 'css' => '.CheckoutDeliveryOption-Button').choose

    assert_equal 1, @browser.button(css: '.CheckoutDeliveryOption-Button').clicks
  end

  def test_a_missing_element_is_not_present_rather_than_an_error
    browser = FakeBrowser.new(missing: [{ id: 'gone' }])

    refute_predicate Bluetir::Field.new(browser, selector('type' => 'button', 'id' => 'gone')),
                     :present?
  end

  # One selector often matches several elements. ScandiPWA lists three delivery
  # options under one class and the FIRST is a free-shipping option the cart
  # does not qualify for, permanently disabled — so clicking the first match
  # waits out the whole timeout for a button the store is refusing to offer.
  def test_choosing_skips_a_match_the_store_has_disabled
    options([false, true]).choose

    assert_equal [0, 1], @browser.matches(:buttons, { css: '.Option' }).map(&:clicks)
  end

  def test_with_nothing_usable_it_still_acts_on_the_first_match
    options([false]).choose

    assert_equal 1, @browser.matches(:buttons, { css: '.Option' }).first.clicks
  end

  private

  # A selector matching several options, each either usable or refused.
  def options(states)
    @browser.set_matches(:buttons, { css: '.Option' },
                         states.map do |enabled|
                           FakeElement.new({ css: '.Option' }, present: true, enabled: enabled)
                         end)
    field('type' => 'button', 'css' => '.Option')
  end

  def selector(definition)
    Bluetir::Selector.new('under test', definition)
  end

  def field(definition)
    Bluetir::Field.new(@browser, selector(definition))
  end
end
