# frozen_string_literal: true

require 'test_helper'

class UrlTest < Minitest::Test
  def test_it_joins_a_relative_path
    assert_equal 'https://s.test/cart', Bluetir::Browser::Url.new('https://s.test').for('cart')
  end

  def test_it_does_not_double_the_slash
    assert_equal 'https://s.test/cart', Bluetir::Browser::Url.new('https://s.test/').for('/cart')
  end

  def test_an_empty_path_is_the_store_itself
    assert_equal 'https://s.test', Bluetir::Browser::Url.new('https://s.test').for('')
    assert_equal 'https://s.test', Bluetir::Browser::Url.new('https://s.test').for(nil)
  end

  def test_an_absolute_url_is_left_alone
    url = Bluetir::Browser::Url.new('https://s.test')

    assert_equal 'https://other.test/x', url.for('https://other.test/x')
  end

  def test_it_appends_the_configured_params
    url = Bluetir::Browser::Url.new('https://s.test', params: { '___store' => 'de' })

    assert_equal 'https://s.test/cart?___store=de', url.for('cart')
  end

  def test_it_keeps_params_the_path_already_had
    url = Bluetir::Browser::Url.new('https://s.test', params: { '___store' => 'de' })

    assert_equal 'https://s.test/c?p=1&___store=de', url.for('c?p=1')
  end

  def test_it_encodes_a_param_that_needs_it
    url = Bluetir::Browser::Url.new('https://s.test', params: { 'q' => 'a b&c' })

    assert_equal 'https://s.test/search?q=a+b%26c', url.for('search')
  end
end
