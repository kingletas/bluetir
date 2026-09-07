# frozen_string_literal: true

require 'test_helper'

class PersonaRunTest < Minitest::Test
  PLACE_ORDER = { css: '.payment-method._active button' }.freeze
  SUCCESS = 'Thank you for your purchase!'

  def setup
    @result = Bluetir::Result.new
    @storefront = Bluetir::Storefront.new(YAML.safe_load(ConfigFixture.storefront))
    @orders = YAML.safe_load(ConfigFixture.orders)
  end

  # The rule this whole mode exists to keep. Everything up to the button, and
  # never the button.
  def test_it_never_clicks_place_order
    browser = FakeBrowser.new(text: SUCCESS)

    assert shopper(browser).call, 'the persona should reach a checkout ready to place'
    assert_equal 0, browser.button(**PLACE_ORDER).clicks
  end

  def test_it_still_reports_the_checkout_as_ready
    browser = FakeBrowser.new(text: SUCCESS)
    shopper(browser).call

    assert_includes @result.checks.map(&:description), 'the order is ready to place'
    assert_predicate @result, :passed?
  end

  # Where exactly it gives up matters less than that it does. A store whose
  # place-order button never appears must never come back as a pass.
  def test_a_missing_place_order_button_fails_rather_than_passing_quietly
    browser = FakeBrowser.new(text: SUCCESS, missing: [PLACE_ORDER])

    refute shopper(browser).call
    refute_predicate @result, :passed?
    assert_match(/checkout/, @result.failure_lines.last)
  end

  def test_it_fills_the_form_with_this_persona_s_own_identity
    browser = FakeBrowser.new(text: SUCCESS)
    who = identity
    shopper(browser, who: who).call

    assert_equal [who.firstname], browser.text_field(name: 'firstname').set_values
    assert_equal [who.email], browser.text_field(id: 'customer-email').set_values
  end

  def test_it_buys_as_many_products_as_the_persona_shops_for
    browser = FakeBrowser.new(text: SUCCESS)
    shopper(browser, persona: archetype('products' => 3)).call

    assert_equal 3, browser.button(id: 'product-addtocart-button').clicks
  end

  def test_it_visits_a_category_only_when_the_persona_browses
    quiet = FakeBrowser.new(text: SUCCESS)
    shopper(quiet, persona: archetype('browses' => false)).call
    browsing = FakeBrowser.new(text: SUCCESS)
    shopper(browsing, persona: archetype('browses' => true)).call

    assert_operator browsing.visited.size, :>, quiet.visited.size
  end

  private

  def archetype(overrides = {})
    Bluetir::Persona.new({ 'name' => 'Test shopper', 'products' => 1 }.merge(overrides))
  end

  def identity
    archetype.identity(Random.new(99))
  end

  # Not named `run`: Minitest::Runnable#run is how the framework executes a
  # test, and defining a private one here stops the whole file dead.
  def shopper(browser, persona: archetype, who: identity)
    context = Bluetir::Flows::Context.new(
      browser: browser, storefront: @storefront, navigator: navigator_for(browser),
      assertions: Bluetir::PageAssertions.new({}), result: @result, screenshots: nil
    )
    Bluetir::Flows::PersonaRun.new(context, persona: persona, identity: who, orders: @orders)
  end
end
