# frozen_string_literal: true

require 'test_helper'

class PersonaTest < Minitest::Test
  ROSTER = {
    'personas' => [
      { 'name' => 'Phone buyer', 'products' => 1, 'viewport' => [390, 844] },
      { 'name' => 'Researcher', 'products' => 3, 'browses' => true, 'searches' => true }
    ]
  }.freeze

  def test_it_reads_a_roster
    roster = Bluetir::Persona.roster(ROSTER)

    assert_equal ['Phone buyer', 'Researcher'], roster.map(&:name)
    assert_equal 3, roster.last.products
  end

  def test_a_roster_with_no_personas_is_refused
    assert_raises(Bluetir::ConfigurationError) { Bluetir::Persona.roster({}) }
    assert_raises(Bluetir::ConfigurationError) { Bluetir::Persona.roster(nil) }
  end

  def test_it_knows_a_phone_from_a_desktop
    roster = Bluetir::Persona.roster(ROSTER)

    refute_predicate roster.first, :desktop?
    assert_predicate roster.last, :desktop?
  end

  # A failing run is only worth anything if it can be repeated, and it can only
  # be repeated if the same seed makes the same person.
  def test_the_same_seed_makes_the_same_person
    one = persona.identity(Random.new(4242))
    two = persona.identity(Random.new(4242))

    assert_equal one, two
  end

  def test_a_different_seed_makes_a_different_person
    people = (1..25).map { |seed| persona.identity(Random.new(seed)).email }

    assert_operator people.uniq.size, :>, 20, 'personas should not collide constantly'
  end

  # A person does not live in a random combination of city, state and postcode,
  # and a store's address validation knows it.
  def test_the_place_is_coherent
    25.times do |seed|
      who = persona.identity(Random.new(seed))

      assert_includes Bluetir::Persona::PLACES, [who.city, who.region, who.postcode]
    end
  end

  def test_the_email_belongs_to_the_person_and_can_never_be_delivered
    who = persona.identity(Random.new(7))

    assert_match(/\A#{who.firstname.downcase}\.#{who.lastname.downcase}\+\d+@/, who.email)
    assert who.email.end_with?('@example.test'), 'example.test is reserved and unroutable'
  end

  def test_every_field_an_address_form_asks_for_is_filled
    who = persona.identity(Random.new(11))

    assert(who.to_h.values.none? { |v| v.to_s.strip.empty? }, "blank field in #{who.to_h}")
  end

  private

  def persona
    Bluetir::Persona.roster(ROSTER).last
  end
end
