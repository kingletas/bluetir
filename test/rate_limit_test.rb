# frozen_string_literal: true

require 'test_helper'

# A throttled run proves nothing about the store, and carrying on makes it worse
# for whoever else is using it. This exists because a demo store was hammered
# into returning 429 and the suite kept going, reporting failures that were ours
# rather than theirs.
class RateLimitTest < Minitest::Test
  def test_it_stops_when_the_store_says_too_many_requests
    browser = FakeBrowser.new(text: '429 Too Many Requests / nginx')

    error = assert_raises(Bluetir::RateLimited) { navigator_for(browser).go('cart') }
    assert_match(/rate limit/, error.message)
  end

  def test_the_message_says_what_to_do_about_it
    browser = FakeBrowser.new(text: 'Rate limit exceeded')

    error = assert_raises(Bluetir::RateLimited) { navigator_for(browser).go('cart') }
    assert_match(/http\.delay/, error.message)
    assert_match(%r{https://store\.test/cart}, error.message)
  end

  def test_an_ordinary_page_is_left_alone
    browser = FakeBrowser.new(text: 'Shopping Cart — 429 items in stock')

    navigator_for(browser).go('cart')

    assert_equal ['https://store.test/cart'], browser.visited
  end

  def test_a_page_it_cannot_read_is_not_called_a_rate_limit
    browser = FakeBrowser.new(text: nil)

    navigator_for(browser).go('cart')

    assert_equal ['https://store.test/cart'], browser.visited
  end
end
