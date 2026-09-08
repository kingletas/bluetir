# frozen_string_literal: true

require 'test_helper'

class NavigatorTest < Minitest::Test
  def test_it_visits_the_built_url
    browser = FakeBrowser.new
    navigator_for(browser).go('cart')

    assert_equal ['https://store.test/cart'], browser.visited
  end

  def test_it_carries_the_params_everywhere
    browser = FakeBrowser.new
    nav = navigator_for(browser, 'https://store.test', params: { '___store' => 'de' })
    nav.go('cart')
    nav.go('checkout')

    assert_equal ['https://store.test/cart?___store=de',
                  'https://store.test/checkout?___store=de'], browser.visited
  end

  # document.readyState is a String. Comparing it to a Symbol is always false,
  # which turned this wait into a full ten-second timeout on every page load —
  # silently, because the settle rescues its own failure.
  def test_it_recognises_a_finished_document_rather_than_timing_out
    browser = FakeBrowser.new
    navigator_for(browser).go('cart')

    assert_equal 0, browser.wait_failures
  end

  def test_the_first_page_is_not_delayed_but_the_next_one_is
    browser = FakeBrowser.new
    nav = Bluetir::Browser::Navigator.new(browser, url: Bluetir::Browser::Url.new('https://store.test'),
                                                   delay: 0.2)

    first = Time.now
    nav.go('a')
    quick = Time.now - first
    nav.go('b')
    total = Time.now - first

    assert_operator quick, :<, 0.15, 'the first load should not wait'
    assert_operator total, :>=, 0.2, 'the second load should wait out the delay'
  end
end
