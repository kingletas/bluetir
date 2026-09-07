# frozen_string_literal: true

require 'test_helper'

class HttpSettingsTest < Minitest::Test
  def test_it_identifies_the_tool_by_default
    settings = Bluetir::HttpSettings.from(nil)

    assert_match(%r{\ABluetir/}, settings.user_agent)
    assert_match(/github\.com/, settings.user_agent)
  end

  def test_it_is_polite_by_default
    assert_in_delta(1.0, Bluetir::HttpSettings.from(nil).delay)
  end

  def test_it_takes_a_user_agent_and_a_delay
    settings = Bluetir::HttpSettings.from('user_agent' => 'Mozilla/5.0', 'delay' => 0.25)

    assert_equal 'Mozilla/5.0', settings.user_agent
    assert_in_delta 0.25, settings.delay
  end

  def test_headers_become_strings
    settings = Bluetir::HttpSettings.from('headers' => { 'X-Debug' => 1 })

    assert_equal({ 'X-Debug' => '1' }, settings.headers)
    assert_predicate settings, :headers?
  end

  def test_params_become_strings
    settings = Bluetir::HttpSettings.from('params' => { '___store' => :default })

    assert_equal({ '___store' => 'default' }, settings.params)
    assert_predicate settings, :params?
  end

  def test_nothing_configured_means_nothing_to_apply
    settings = Bluetir::HttpSettings.from({})

    refute_predicate settings, :headers?
    refute_predicate settings, :cookies?
    refute_predicate settings, :params?
  end

  def test_a_cookie_keeps_the_attributes_it_was_given
    settings = Bluetir::HttpSettings.from(
      'cookies' => [{ 'name' => 'store', 'value' => 'default', 'domain' => '.example.test' }]
    )

    assert_equal 1, settings.cookies.size
    assert_equal({ name: 'store', value: 'default', domain: '.example.test' }, settings.cookies.first)
  end

  def test_a_cookie_without_a_name_is_refused
    assert_raises(Bluetir::ConfigurationError) do
      Bluetir::HttpSettings.from('cookies' => [{ 'value' => 'x' }])
    end
  end

  def test_a_cookie_that_is_not_a_mapping_is_refused
    assert_raises(Bluetir::ConfigurationError) do
      Bluetir::HttpSettings.from('cookies' => ['store=default'])
    end
  end

  def test_local_storage_becomes_strings
    settings = Bluetir::HttpSettings.from('local_storage' => { 'seen_notice' => true })

    assert_equal({ 'seen_notice' => 'true' }, settings.local_storage)
    assert_predicate settings, :local_storage?
  end

  def test_nothing_stored_means_nothing_to_seed
    refute_predicate Bluetir::HttpSettings.from({}), :local_storage?
  end

  def test_the_summary_says_what_is_configured
    settings = Bluetir::HttpSettings.from('headers' => { 'A' => 'b' }, 'delay' => 2)

    assert_match(/1 header/, settings.summary)
    assert_match(/delay 2.0s/, settings.summary)
  end
end
