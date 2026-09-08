# frozen_string_literal: true

require 'test_helper'

class ProbeTest < Minitest::Test
  def setup
    @result = Bluetir::Report::Result.new
    @browser = FakeBrowser.new(missing: [{ id: 'checkmo' }])
    @storefront = Bluetir::Storefront.new(YAML.safe_load(ConfigFixture.storefront))
  end

  def test_it_records_where_each_selector_was_seen
    seen = probe.run.to_h { |s| [s.name, s.pages] }

    assert_includes seen['add_to_cart_button'], 'home'
    assert_empty seen['payment_method']
  end

  def test_it_records_where_every_page_landed
    landings = probe.tap(&:run).landings

    assert_equal %w[home product cart checkout], landings.map(&:label)
    assert(landings.all? { |l| l.asked == l.got }, 'the fake browser never redirects')
  end

  # A selector on a step the probe never drives to is not missing. Calling it
  # missing trains you to ignore the column that reports real breakage.
  def test_a_selector_on_an_unvisited_stage_is_reported_not_failed
    staged = YAML.safe_load(ConfigFixture.storefront)
    staged['selectors']['payment_method']['stage'] = 'payment'
    @storefront = Bluetir::Storefront.new(staged)
    sighting = probe.run.find { |s| s.name == 'payment_method' }

    assert_equal 'payment', sighting.unreached_stage
  end

  def test_a_selector_with_no_stage_is_simply_missing
    sighting = probe.run.find { |s| s.name == 'payment_method' }

    assert_nil sighting.unreached_stage
    assert_empty sighting.pages
  end

  # Asking for https://shop.test and landing on https://shop.test/ is the same
  # page. Calling it a redirect is an alarm that fires when nothing is wrong.
  def test_a_trailing_slash_on_the_root_is_not_a_redirect
    browser = FakeBrowser.new
    def browser.goto(url)
      super
      @url = "#{url}/"
    end
    result = Bluetir::Report::Result.new
    probe_with(browser, result).run

    landing_failures = result.failures.select { |c| c.description.include?('page loads') }

    assert_empty landing_failures
  end

  private

  def probe_with(browser, result)
    context = Bluetir::Flows::Context.new(
      browser: browser, storefront: @storefront, navigator: navigator_for(browser),
      assertions: Bluetir::Checks::PageAssertions.new({}), result: result, screenshots: nil
    )
    Bluetir::Checks::Probe.new(context, YAML.safe_load(ConfigFixture.orders))
  end

  def probe
    context = Bluetir::Flows::Context.new(
      browser: @browser, storefront: @storefront, navigator: navigator_for(@browser),
      assertions: Bluetir::Checks::PageAssertions.new({}), result: @result, screenshots: nil
    )
    Bluetir::Checks::Probe.new(context, YAML.safe_load(ConfigFixture.orders))
  end
end
