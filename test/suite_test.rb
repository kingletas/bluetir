# frozen_string_literal: true

require 'test_helper'

class SuiteTest < Minitest::Test
  def test_it_refuses_an_assertions_file_that_asserts_nothing
    in_config_dir(assertions: "cart:\n") do |path|
      suite = Bluetir::Suite.new(Bluetir::Configuration.load(path), output: StringIO.new)
      error = assert_raises(Bluetir::ConfigurationError) { suite.run }

      assert_match(/could never fail/, error.message)
    end
  end

  def test_it_refuses_a_mode_it_does_not_have
    in_config_dir do |path|
      assert_raises(Bluetir::ConfigurationError) do
        Bluetir::Suite.new(Bluetir::Configuration.load(path), mode: 'wombat')
      end
    end
  end

  def test_the_plan_reports_what_the_run_would_cover
    in_config_dir do |path|
      plan = Bluetir::Suite.new(Bluetir::Configuration.load(path), output: StringIO.new).plan

      assert_includes plan.join("\n"), 'Test store (magento2)'
      assert_includes plan.join("\n"), 'products:   1'
    end
  end

  # A shopper inheriting the previous one's cart is not a person. Clearing
  # cookies between them was worse than useless: a storefront ties its form key
  # to the session the page was rendered for, so the next add to cart failed in
  # a way that looked like a broken store.
  def test_persona_mode_opens_a_browser_for_every_shopper
    in_config_dir(personas: 3) do |path|
      suite = Bluetir::Suite.new(Bluetir::Configuration.load(path), mode: 'persona',
                                                                    output: StringIO.new)
      opened = 0
      suite.define_singleton_method(:session) do
        opened += 1
        Object.new.tap { |fake| fake.define_singleton_method(:open) { |&block| block.call(nil) } }
      end
      suite.define_singleton_method(:build_context) { |_browser, _result| nil }
      suite.define_singleton_method(:notify) { |_result| nil }
      without_really_shopping { suite.run }

      assert_equal 3, opened, 'one browser per shopper'
    end
  end

  # Three modes were once deleted by an edit that removed more than it meant to,
  # and every test stayed green because nothing checked that a listed mode has
  # an implementation. The first thing that noticed was a live store.
  def test_every_mode_has_an_implementation
    Bluetir::Suite::HANDLERS.each do |mode, handler|
      # Asked of the class rather than of an instance: the handlers are private,
      # and assert_respond_to cannot see a private method — which is what an
      # autocorrect quietly turned this check into the first time it was written.
      assert Bluetir::Suite.private_method_defined?(handler), "mode #{mode} has no #{handler}"
    end
  end

  def test_every_handler_is_reachable_as_a_mode
    assert_equal Bluetir::Suite::HANDLERS.keys.sort, Bluetir::Suite::MODES.sort
  end

  private

  # Redefining a method on a real class outlives the test that did it and
  # poisons whichever test minitest happens to run next, so it is put back.
  def without_really_shopping
    original = Bluetir::Checks::Shoppers.instance_method(:visit)
    Bluetir::Checks::Shoppers.define_method(:visit) { |*| true }
    yield
  ensure
    Bluetir::Checks::Shoppers.define_method(:visit, original)
  end

  def in_config_dir(assertions: nil, personas: nil)
    Dir.mktmpdir do |dir|
      extra = assertions ? 'assertions: a.yml' : ''
      extra += "\npersonas: people.yml" if personas
      files = { 'bluetir.yml' => ConfigFixture.config(extra),
                'storefronts/test.yml' => ConfigFixture.storefront,
                'orders/test.yml' => ConfigFixture.orders }
      files['a.yml'] = assertions if assertions
      if personas
        people = (1..personas).map { |i| "  - name: Shopper #{i}\n    products: 1" }.join("\n")
        files['people.yml'] = "personas:\n#{people}\n"
      end
      yield ConfigFixture.write(dir, files)
    end
  end
end
