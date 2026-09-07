# frozen_string_literal: true

module Bluetir
  # One shopper: who they are, and how they shop.
  #
  # A persona is an archetype rather than a person — "someone on a phone who
  # buys one thing" — and every run gives it a fresh invented identity. That is
  # both more realistic and safer: a real store treats a repeat email as a
  # returning customer, and nobody's actual name belongs in a test.
  #
  # The identity is drawn from a seeded generator, so a run that fails can be
  # repeated exactly by passing its seed back.
  class Persona
    Identity = Data.define(:firstname, :lastname, :email, :street, :city,
                           :region, :postcode, :country, :telephone)

    FIRST_NAMES = %w[
      Ada Blythe Casimir Delphine Emeka Fenna Gideon Hana Ines Jonas
      Kwame Lucia Mateo Noor Oskar Priya Quentin Rosa Soren Tamsin
    ].freeze

    LAST_NAMES = %w[
      Achterberg Bellweather Costa Dunmore Eriksson Farrow Grimaldi Halloran
      Ibarra Jorgensen Kaminski Lindqvist Moreau Nakamura Okonkwo Pereira
      Rasmussen Steadman Vasquez Whitlock
    ].freeze

    STREETS = %w[
      Alder Birchwood Cobblestone Draycott Elmfield Fernbank Gravesend
      Harrowgate Ironmonger Juniper Kestrel Larkspur Marlowe Northgate
    ].freeze

    # City, region and postcode kept together, because a person does not live in
    # a random combination of the three and a store's address validation knows it.
    PLACES = [
      %w[Austin Texas 78701], %w[Dallas Texas 75201], %w[Columbus Ohio 43215],
      %w[Cleveland Ohio 44113], %w[Portland Oregon 97205], %w[Salem Oregon 97301],
      %w[Denver Colorado 80202], %w[Boulder Colorado 80302], %w[Tucson Arizona 85701],
      %w[Savannah Georgia 31401], %w[Madison Wisconsin 53703], %w[Boise Idaho 83702]
    ].freeze

    DEFAULT_COUNTRY = 'United States'

    # example.test is reserved by RFC 6761 and can never reach a real mailbox.
    EMAIL_DOMAIN = 'example.test'

    attr_reader :name, :products, :viewport, :browses, :searches

    def self.roster(data)
      entries = Array(data && data['personas'])
      raise ConfigurationError, 'the persona file defines no personas' if entries.empty?

      entries.map { |entry| new(entry) }
    end

    def initialize(entry)
      @name = entry['name'] || 'Unnamed shopper'
      @products = Integer(entry['products'] || 1)
      @viewport = Array(entry['viewport']).map(&:to_i)
      @browses = entry.fetch('browses', false)
      @searches = entry.fetch('searches', false)
    end

    def desktop?
      @viewport.empty? || @viewport.first >= 768
    end

    # A fresh person, reproducible from the seed that made them.
    def identity(random)
      first = FIRST_NAMES.sample(random: random)
      last = LAST_NAMES.sample(random: random)
      city, region, postcode = PLACES.sample(random: random)
      Identity.new(
        firstname: first, lastname: last, email: address_for(first, last, random),
        street: "#{random.rand(20..9999)} #{STREETS.sample(random: random)} Street",
        city: city, region: region, postcode: postcode, country: DEFAULT_COUNTRY,
        telephone: "512555#{format('%04d', random.rand(0..9999))}"
      )
    end

    def to_s
      bits = ["#{@products} product(s)"]
      bits << 'browses a category' if @browses
      bits << 'searches' if @searches
      bits << (desktop? ? 'desktop' : 'mobile')
      "#{@name} — #{bits.join(', ')}"
    end

    private

    def address_for(first, last, random)
      "#{first.downcase}.#{last.downcase}+#{random.rand(100_000..999_999)}@#{EMAIL_DOMAIN}"
    end
  end
end
