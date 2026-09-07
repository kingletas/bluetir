# frozen_string_literal: true

module Bluetir
  # Takes one persona through the store and says how far they got.
  class Shoppers
    def initialize(configuration, output)
      @configuration = configuration
      @output = output
    end

    # Shops as one persona. The browser they arrive in is the caller's to open,
    # because every shopper needs their own.
    def visit(context, persona, identity)
      say "  #{persona} — #{identity.firstname} #{identity.lastname} of #{identity.city}"
      ready = Flows::PersonaRun.new(context, persona: persona, identity: identity,
                                             orders: @configuration.orders).call
      say "    #{ready ? 'reached a checkout ready to place' : 'DID NOT reach the last step'}"
      ready
    end

    private

    def say(message)
      @output.puts(message)
    end
  end
end
