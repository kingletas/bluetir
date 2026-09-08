# frozen_string_literal: true

require 'test_helper'
require_relative 'fixture_store'

# Captures a baseline from a real browser, breaks the store, and checks that the
# break is reported as a regression.
#
# Opt in with `rake test:browser`. This is the acceptance feature end to end:
# everything else about it is decided by unit tests, but whether a real page
# whose button has been renamed is actually caught can only be answered here.
class AcceptanceTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('bluetir-acceptance')
    @root = FixtureStore.build(@dir)
    @storefront = Bluetir::Storefront.load(@root.join('storefront.yml'))
    @baseline_file = @root.join('baseline.yml')
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_a_store_that_has_not_changed_reports_no_drift
    capture
    result = Bluetir::Report::Result.new
    in_browser(result) { |a| a.compare(store: store, against: @baseline_file) }

    assert_predicate result, :passed?
    # Filling the cart is part of probing, so a cart check rides along. What
    # matters is that the acceptance comparison itself found nothing to say.
    assert_includes result.checks.map(&:section), 'acceptance'
    assert_empty result.failures
  end

  # The break this whole feature exists to catch: a button that used to be
  # there and is not. No assertions file mentions it; the baseline does.
  def test_a_renamed_button_is_reported_as_a_regression
    capture
    break_the_add_to_cart_button
    result = Bluetir::Report::Result.new
    in_browser(result) { |a| a.compare(store: store, against: @baseline_file) }

    refute_predicate result, :passed?
    assert_match(/add_to_cart_button/, result.failure_lines.join)
  end

  def test_the_baseline_it_writes_can_be_read_back
    capture

    assert_predicate @baseline_file, :file?
    back = Bluetir::Checks::Baseline.load(@baseline_file)

    assert_includes back.selectors.keys, 'add_to_cart_button'
    assert_equal store, back.store
  end

  private

  def store
    "file://#{@root}"
  end

  def break_the_add_to_cart_button
    page = @root.join('product.html')
    page.write(page.read.sub('id="product-addtocart-button"', 'id="buy-it-now"'))
  end

  def capture
    in_browser(Bluetir::Report::Result.new) do |acceptance|
      acceptance.capture(store: store, to: @baseline_file)
    end
  end

  def in_browser(result)
    session = Bluetir::Browser::Session.new(base_url: store, http: Bluetir::Browser::HttpSettings.from({}),
                                            timeout: 10, headless: true)
    session.open do |browser|
      context = Bluetir::Flows::Context.new(
        browser: browser, storefront: @storefront, navigator: navigator_for(browser, store),
        assertions: Bluetir::Checks::PageAssertions.new({}), result: result, screenshots: nil
      )
      yield Bluetir::Checks::Acceptance.new(context, orders, StringIO.new)
    end
  end

  def orders
    { 'products' => [{ 'url' => 'product.html', 'qty' => 1 }] }
  end
end
