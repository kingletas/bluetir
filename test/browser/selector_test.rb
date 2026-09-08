# frozen_string_literal: true

require 'test_helper'

class SelectorTest < Minitest::Test
  def test_it_finds_the_element_its_type_names
    selector = Bluetir::Browser::Selector.new('add_to_cart', 'type' => 'button', 'id' => 'go')
    element = selector.on(FakeBrowser.new)

    assert_equal({ id: 'go' }, element.locator)
  end

  def test_it_defaults_to_a_generic_element
    selector = Bluetir::Browser::Selector.new('anything', 'css' => '.thing')

    assert_equal 'element', selector.type
  end

  def test_it_refuses_a_type_watir_does_not_have
    error = assert_raises(Bluetir::ConfigurationError) do
      Bluetir::Browser::Selector.new('bad', 'type' => 'wombat', 'id' => 'x')
    end

    assert_match(/unknown type/, error.message)
  end

  def test_it_refuses_a_selector_with_nothing_to_locate
    assert_raises(Bluetir::ConfigurationError) do
      Bluetir::Browser::Selector.new('empty', 'type' => 'button')
    end
  end

  def test_it_ignores_keys_that_are_not_locators
    selector = Bluetir::Browser::Selector.new('option', 'type' => 'select_list', 'id' => 'size',
                                                        'select' => 'M', 'delay' => 2)

    assert_equal({ id: 'size' }, selector.locator)
  end
end
