# frozen_string_literal: true

require 'test_helper'

class PageAssertionsTest < Minitest::Test
  def setup
    @result = Bluetir::Report::Result.new
    expectations = {
      'cart' => [{ 'expect' => ['Shopping Cart', 'Estimate Shipping'] }],
      'success' => [{ 'expect' => ['Thank you'] }]
    }
    @page_assertions = Bluetir::Checks::PageAssertions.new(expectations)
  end

  def test_an_empty_file_is_not_configured
    refute_predicate Bluetir::Checks::PageAssertions.new({}), :configured?
    refute_predicate Bluetir::Checks::PageAssertions.new(nil), :configured?
  end

  def test_it_counts_every_expectation_across_sections
    assert_equal 3, @page_assertions.expectations
    assert_predicate @page_assertions, :configured?
  end

  def test_it_passes_when_the_text_is_on_the_page
    @page_assertions.verify(FakeBrowser.new(text: 'Shopping Cart — Estimate Shipping'), 'cart', @result)

    assert_equal 2, @result.passed
    assert_equal 0, @result.failed
  end

  # A storefront that renders its cart in JavaScript puts the text there after
  # the document is done. Checking once fails on timing rather than on content,
  # and intermittently, which is worse than failing.
  def test_it_waits_for_text_that_arrives_late
    browser = FakeBrowser.new(text: 'still loading')
    Thread.new do
      sleep 1
      browser.text = 'Shopping Cart — Estimate Shipping'
    end
    @page_assertions.verify(browser, 'cart', @result)

    assert_equal 2, @result.passed
  end

  def test_it_fails_for_each_string_that_is_missing
    @page_assertions.verify(FakeBrowser.new(text: 'Shopping Cart'), 'cart', @result)

    assert_equal 1, @result.failed
    assert_match(/Estimate Shipping/, @result.failure_lines.first)
  end

  # The commonest reason a string is missing is that the browser is somewhere
  # else entirely, and without the url that is indistinguishable from a store
  # that changed its wording.
  def test_a_failure_names_the_page_it_happened_on
    browser = FakeBrowser.new(text: 'nothing expected here')
    browser.goto('https://store.test/somewhere-else')
    @page_assertions.verify(browser, 'cart', @result)

    assert_match(%r{on https://store\.test/somewhere-else}, @result.failure_lines.first)
  end

  # A missing string and a page that never painted look identical in a report,
  # and they are completely different problems.
  def test_a_failure_shows_what_the_page_did_say
    @page_assertions.verify(FakeBrowser.new(text: 'An error has occurred'), 'cart', @result)

    assert_match(/the page said: "An error has occurred"/, @result.failure_lines.first)
  end

  def test_a_page_with_no_text_at_all_says_so
    @page_assertions.verify(FakeBrowser.new(text: ''), 'cart', @result)

    assert_match(/no text at all/, @result.failure_lines.first)
  end

  def test_a_section_with_no_entry_records_nothing
    @page_assertions.verify(FakeBrowser.new(text: 'anything'), 'product', @result)

    assert_equal 0, @result.total
  end

  def test_a_sweep_visits_every_url_it_is_given
    browser = FakeBrowser.new(text: 'Welcome')
    sweepable.sweep(browser, navigator_for(browser), @result)

    assert_equal ['https://store.test/thing.html'], browser.visited
  end

  # An entry with no url of its own belongs to a page a flow reaches. Sweeping
  # it would load the home page and test it for text that lives elsewhere.
  def test_a_sweep_leaves_an_entry_with_no_url_to_its_flow
    browser = FakeBrowser.new(text: 'Welcome')
    sweepable.sweep(browser, navigator_for(browser), @result)

    assert_equal 1, @result.total
  end

  # An entry naming a url is about THAT page. A shopper buying three products
  # visits three product pages, and asserting the first one's name on all three
  # is a failure that says nothing about the store.
  def test_verify_ignores_an_entry_that_names_its_own_page
    browser = FakeBrowser.new(text: 'a completely different product')
    sweepable.verify(browser, 'product', @result)

    assert_equal 0, @result.total
  end

  def test_an_entry_with_no_url_is_still_checked_in_place
    browser = FakeBrowser.new(text: 'Welcome')
    sweepable.verify(browser, 'cart', @result)

    assert_equal 1, @result.passed
  end

  # An empty url is the home page, declared. A missing url key is not a page.
  def test_a_sweep_treats_an_empty_url_as_the_home_page
    browser = FakeBrowser.new(text: 'Welcome')
    home = Bluetir::Checks::PageAssertions.new({ 'home' => [{ 'url' => '', 'expect' => ['Welcome'] }] })
    home.sweep(browser, navigator_for(browser), @result)

    assert_equal ['https://store.test'], browser.visited
  end

  def sweepable
    Bluetir::Checks::PageAssertions.new({
                                          'cart' => [{ 'expect' => ['Welcome'] }],
                                          'product' => [{ 'url' => '/thing.html',
                                                          'expect' => ['Welcome'] }]
                                        })
  end

  def test_a_bare_string_is_accepted_as_an_expectation
    assertions = Bluetir::Checks::PageAssertions.new({ 'home' => ['Welcome'] })
    assertions.verify(FakeBrowser.new(text: 'Welcome home'), 'home', @result)

    assert_equal 1, @result.passed
  end
end
