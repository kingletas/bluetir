# frozen_string_literal: true

require 'test_helper'

class ShoppersTest < Minitest::Test
  def setup
    @browser = FakeBrowser.new(text: 'Thank you for your purchase!')
    @storefront = Bluetir::Storefront.new(YAML.safe_load(ConfigFixture.storefront))
    @result = Bluetir::Result.new
    @output = StringIO.new
  end

  def test_it_names_the_shopper_and_where_they_got_to
    assert visit

    assert_match(/Phone buyer/, @output.string)
    assert_match(/reached a checkout ready to place/, @output.string)
  end

  def test_it_says_plainly_when_a_shopper_did_not_get_there
    @browser = FakeBrowser.new(text: 'Thank you', missing: [{ id: 'customer-email' }])

    refute visit
    assert_match(/DID NOT reach the last step/, @output.string)
  end

  def test_it_names_the_person_rather_than_only_the_archetype
    visit

    assert_match(/of [A-Z][a-z]+/, @output.string, 'the shopper should be a named person somewhere')
  end

  private

  def persona
    Bluetir::Persona.new('name' => 'Phone buyer', 'products' => 1)
  end

  def visit
    Bluetir::Shoppers.new(configuration, @output)
                     .visit(context, persona, persona.identity(Random.new(3)))
  end

  def context
    Bluetir::Flows::Context.new(
      browser: @browser, storefront: @storefront, navigator: navigator_for(@browser),
      assertions: Bluetir::PageAssertions.new({}), result: @result, screenshots: nil
    )
  end

  def configuration
    Struct.new(:orders).new(YAML.safe_load(ConfigFixture.orders))
  end
end
