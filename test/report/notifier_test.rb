# frozen_string_literal: true

require 'test_helper'

class NotifierTest < Minitest::Test
  def test_it_is_not_configured_without_recipients
    notifier = Bluetir::Report::Notifier.new(recipients: [], sender: 'a@b.test', server: 'localhost')

    refute_predicate notifier, :configured?
  end

  def test_it_is_not_configured_without_a_server
    notifier = Bluetir::Report::Notifier.new(recipients: ['a@b.test'], sender: 'a@b.test', server: nil)

    refute_predicate notifier, :configured?
  end

  def test_it_sends_nothing_when_nobody_is_configured
    notifier = Bluetir::Report::Notifier.new(recipients: [], sender: 'a@b.test', server: nil)

    refute notifier.deliver(Bluetir::Report::Result.new, 'https://store.test')
  end

  def test_the_subject_says_a_failing_run_failed
    result = Bluetir::Report::Result.new
    result.pass('cart', 'added')
    result.fail('success', 'placed', 'no confirmation')

    assert_match(/1 checks FAILED/, subject_for(result))
  end

  def test_the_subject_says_a_passing_run_passed
    result = Bluetir::Report::Result.new
    result.pass('cart', 'added')

    assert_match(/all checks passed/, subject_for(result))
  end

  def test_the_subject_refuses_to_call_an_empty_run_a_success
    assert_match(/nothing was proven/, subject_for(Bluetir::Report::Result.new))
  end

  private

  def subject_for(result)
    notifier = Bluetir::Report::Notifier.new(recipients: ['a@b.test'], sender: 'a@b.test', server: 'x')
    notifier.send(:subject, result)
  end
end
