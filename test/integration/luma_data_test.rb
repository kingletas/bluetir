# frozen_string_literal: true

require 'test_helper'
require 'yaml'
require_relative 'fixture_store'

# Drives the Luma order and success expectations bluetir ships against the fixture's copy of Luma's markup.
#
# Opt in with `rake test:browser`. These read etc/ directly, so a wrong shipped file fails here.
class LumaDataTest < Minitest::Test
  ETC = Pathname.new(__dir__).join('../../etc').expand_path
  EMAIL_LINE = "We'll email you an order confirmation"

  def setup
    @dir = Dir.mktmpdir('bluetir-luma')
    @root = FixtureStore.build(@dir)
    @storefront = Bluetir::Storefront.load(@root.join('storefront.yml'))
    @result = Bluetir::Report::Result.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_the_shipped_swatch_options_add_the_configurable_product
    in_browser do |context|
      assert Bluetir::Flows::AddToCart.new(context).call(configurable), "add failed: #{what_failed}"
      assert_equal %w[M Purple], chosen_swatches(context.browser)
    end

    assert_predicate @result, :passed?
  end

  def test_a_swatch_left_unchosen_keeps_the_product_out_of_the_cart
    size_only = configurable.merge('options' => configurable['options'].first(1))

    in_browser(timeout: 3) do |context|
      refute Bluetir::Flows::AddToCart.new(context).call(size_only)
    end

    assert_match(/added configurable.html to the cart/, what_failed)
  end

  def test_the_shipped_success_expectations_hold_for_a_guest_order
    in_browser { |context| assert place_order(context), "checkout failed: #{what_failed}" }

    assert_predicate @result, :passed?
    assert_includes @result.checks.map(&:description), "page contains #{EMAIL_LINE.inspect}"
  end

  def test_the_shipped_success_expectations_hold_for_a_customer_who_can_view_the_order
    rewrite_success(FixtureStore::GUEST_ORDER_NUMBER, FixtureStore::CUSTOMER_ORDER_NUMBER)

    in_browser { |context| assert place_order(context), "checkout failed: #{what_failed}" }

    assert_predicate @result, :passed?
  end

  def test_a_success_page_that_names_no_order_fails_the_shipped_expectations
    rewrite_success(FixtureStore::GUEST_ORDER_NUMBER, '')
    rewrite_success(FixtureStore::ORDER_EMAIL, '')
    in_browser { |context| place_order(context) }

    refute_predicate @result, :passed?
    assert(@result.failures.all? { |check| check.section == 'success' })
    assert_includes what_failed, EMAIL_LINE
  end

  private

  def configurable
    YAML.safe_load_file(ETC.join('orders/luma.yml'))['products']
        .find { |product| product['options'] }
        .merge('url' => 'configurable.html')
  end

  def success_expectations
    YAML.safe_load_file(ETC.join('assertions/magento2.yml')).slice('success')
  end

  def place_order(context)
    Bluetir::Flows::Checkout.new(context).call('email' => 'buyer@example.test', 'address' => address)
  end

  def chosen_swatches(browser)
    browser.divs(css: '.swatch-option.selected').map { |swatch| swatch.attribute_value('data-option-label') }
  end

  # A replacement that matched nothing would leave the page as it was and pass for the wrong reason.
  def rewrite_success(from, to)
    page = @root.join('checkout.html')

    assert_includes page.read, from
    page.write(page.read.sub(from, to))
  end

  def what_failed
    @result.failure_lines.join('; ')
  end

  def address
    { 'firstname' => 'Test', 'lastname' => 'Order', 'street' => '1 Test Street',
      'city' => 'Austin', 'region' => 'Texas', 'postcode' => '78701',
      'country' => 'United States', 'telephone' => '5125550100' }
  end

  def in_browser(timeout: 10)
    base_url = "file://#{@root}"
    assertions = Bluetir::Checks::PageAssertions.new(success_expectations, arrival_timeout: 1)
    session = Bluetir::Browser::Session.new(base_url: base_url, http: Bluetir::Browser::HttpSettings.from({}),
                                            timeout: timeout, headless: true)
    session.open do |b|
      yield Bluetir::Flows::Context.new(browser: b, storefront: @storefront,
                                        navigator: navigator_for(b, base_url),
                                        assertions: assertions, result: @result, screenshots: nil)
    end
  end
end
