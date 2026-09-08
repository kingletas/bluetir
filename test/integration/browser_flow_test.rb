# frozen_string_literal: true

require 'test_helper'
require_relative 'fixture_store'

# Drives the real flows through a real browser against a static storefront.
#
# Opt in with `rake test:browser`. It is out of the default suite so that a commit
# never waits on a browser, and it needs no Magento to prove the selectors resolve.
class BrowserFlowTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('bluetir-fixture')
    @root = FixtureStore.build(@dir)
    @storefront = Bluetir::Storefront.load(@root.join('storefront.yml'))
    @result = Bluetir::Report::Result.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_it_adds_a_product_and_places_an_order_in_a_real_browser
    in_browser do |context|
      Bluetir::Flows::AddToCart.new(context).call('url' => 'product.html', 'qty' => 3)
      Bluetir::Flows::ShippingQuote.new(context).call(address)
      placed = Bluetir::Flows::Checkout.new(context).call('email' => 'buyer@example.test',
                                                          'address' => address)

      assert placed, "checkout failed: #{@result.failure_lines.join('; ')}"
      assert_predicate @result, :passed?
    end
  end

  def test_it_reports_a_failure_instead_of_raising_when_the_order_never_confirms
    @root.join('checkout.html').write(
      @root.join('checkout.html').read.sub(FixtureStore::SUCCESS_TEXT, 'An error has occurred')
    )
    in_browser(timeout: 3) do |context|
      refute Bluetir::Flows::Checkout.new(context).call('email' => 'buyer@example.test',
                                                        'address' => address)
      refute_predicate @result, :passed?
      assert_match(/the order was placed/, @result.failure_lines.last)
    end
  end

  def test_the_assertions_it_runs_can_actually_fail
    assertions = Bluetir::Checks::PageAssertions.new({ 'product' => [{ 'expect' => ['In stock',
                                                                                    'Not on this page'] }] })
    in_browser(assertions: assertions) do |context|
      Bluetir::Flows::AddToCart.new(context).call('url' => 'product.html')

      assert_equal(1, @result.failures.count { |c| c.section == 'product' })
      assert_includes @result.checks.map(&:description), 'page contains "In stock"'
    end
  end

  private

  def address
    { 'firstname' => 'Test', 'lastname' => 'Order', 'street' => '1 Test Street',
      'city' => 'Austin', 'region' => 'Texas', 'postcode' => '78701',
      'country' => 'United States', 'telephone' => '5125550100' }
  end

  def in_browser(timeout: 10, assertions: Bluetir::Checks::PageAssertions.new({}))
    base_url = "file://#{@root}"
    session = Bluetir::Browser::Session.new(base_url: base_url, http: Bluetir::Browser::HttpSettings.from({}),
                                            timeout: timeout, headless: true)
    session.open do |b|
      yield Bluetir::Flows::Context.new(browser: b, storefront: @storefront,
                                        navigator: navigator_for(b, base_url),
                                        assertions: assertions, result: @result, screenshots: nil)
    end
  end
end
