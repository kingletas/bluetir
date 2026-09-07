# frozen_string_literal: true

require 'test_helper'

class BaselineTest < Minitest::Test
  def setup
    @was = baseline(
      pages: { 'checkout' => 'https://s.test/checkout/' },
      titles: { 'product' => 'Fusion Backpack' },
      selectors: { 'add_to_cart_button' => ['product'], 'checkout_email' => ['checkout'] }
    )
  end

  def test_an_unchanged_store_drifts_not_at_all
    assert_empty @was.drift_from(@was)
  end

  # The whole point: a selector that used to resolve and now does not.
  def test_a_lost_selector_is_a_regression
    now = baseline(
      pages: { 'checkout' => 'https://s.test/checkout/' },
      titles: { 'product' => 'Fusion Backpack' },
      selectors: { 'add_to_cart_button' => ['product'], 'checkout_email' => [] }
    )
    drift = @was.drift_from(now).find { |d| d.subject == 'checkout_email' }

    assert_equal :selector_lost, drift.kind
    assert Bluetir::Baseline.regression?(drift)
    assert_equal 'nowhere', drift.now
  end

  def test_a_selector_that_moved_page_is_reported_but_is_not_a_regression
    now = baseline(selectors: { 'add_to_cart_button' => ['cart'], 'checkout_email' => ['checkout'] })
    drift = @was.drift_from(now).find { |d| d.subject == 'add_to_cart_button' }

    assert_equal :selector_moved, drift.kind
    refute Bluetir::Baseline.regression?(drift)
  end

  # A checkout that answers from the cart is a store turning customers away.
  def test_a_page_that_now_redirects_is_a_regression
    now = baseline(pages: { 'checkout' => 'https://s.test/checkout/cart/' })
    drift = @was.drift_from(now).find { |d| d.kind == :page_moved }

    assert Bluetir::Baseline.regression?(drift)
    assert_equal 'https://s.test/checkout/cart/', drift.now
  end

  def test_a_new_selector_is_reported_and_is_not_a_regression
    now = baseline(selectors: { 'add_to_cart_button' => ['product'],
                                'checkout_email' => ['checkout'],
                                'gift_message' => ['cart'] })
    drift = @was.drift_from(now).find { |d| d.subject == 'gift_message' }

    assert_equal :selector_new, drift.kind
    refute Bluetir::Baseline.regression?(drift)
  end

  def test_a_changed_title_is_reported_and_is_not_a_regression
    now = baseline(titles: { 'product' => 'Fusion Backpack (New!)' })
    drift = @was.drift_from(now).find { |d| d.kind == :title_changed }

    refute Bluetir::Baseline.regression?(drift)
  end

  def test_it_survives_a_round_trip_through_a_file
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join('nested', 'baseline.yml')
      @was.write(path)
      back = Bluetir::Baseline.load(path)

      assert_empty @was.drift_from(back)
      assert_equal @was.store, back.store
    end
  end

  def test_a_missing_baseline_says_so
    assert_raises(Bluetir::ConfigurationError) do
      Bluetir::Baseline.load(Pathname.new('/nowhere/baseline.yml'))
    end
  end

  # Magento's checkout moves between #shipping and #payment as a customer
  # advances, so a fragment in a recorded page would fire on every good run.
  def test_a_captured_page_drops_its_fragment
    landing = Struct.new(:label, :asked, :got, keyword_init: true)
                    .new(label: 'checkout', asked: 'https://s.test/checkout/',
                         got: 'https://s.test/checkout/#shipping')
    captured = Bluetir::Baseline.capture(store: 'https://s.test', landings: [landing],
                                         sightings: [], titles: {})

    assert_equal 'https://s.test/checkout/', captured.pages['checkout']
  end

  private

  def baseline(pages: { 'checkout' => 'https://s.test/checkout/' },
               titles: { 'product' => 'Fusion Backpack' },
               selectors: { 'add_to_cart_button' => ['product'], 'checkout_email' => ['checkout'] })
    Bluetir::Baseline.new('captured_at' => '2026-09-07T00:00:00Z', 'store' => 'https://s.test',
                          'pages' => pages, 'titles' => titles, 'selectors' => selectors)
  end
end
