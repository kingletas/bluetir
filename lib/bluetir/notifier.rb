# frozen_string_literal: true

require 'net/smtp'

module Bluetir
  # Emails the outcome of a run to the configured recipients.
  #
  # Silent when nobody is configured to receive it, and the subject always states
  # what actually happened rather than that the run reached the end.
  class Notifier
    def initialize(recipients:, sender:, server: nil)
      @recipients = Array(recipients)
      @sender = sender
      @server = server
    end

    def configured?
      !@recipients.empty? && !@server.nil?
    end

    # Sends the result, and reports a delivery failure without failing the run.
    def deliver(result, base_url)
      return false unless configured?

      Net::SMTP.start(@server) do |smtp|
        @recipients.each { |to| smtp.send_message(message(result, base_url, to), @sender, to) }
      end
      true
    rescue StandardError => e
      warn "[warn] could not send the run report: #{e.message}"
      false
    end

    private

    def subject(result)
      return 'bluetir: nothing was proven, no checks ran' if result.total.zero?

      result.passed? ? 'bluetir: all checks passed' : "bluetir: #{result.failed} checks FAILED"
    end

    def message(result, base_url, recipient)
      <<~MAIL
        From: bluetir <#{@sender}>
        To: <#{recipient}>
        Subject: #{subject(result)}

        Store:  #{base_url}
        Result: #{result.summary}

        #{result.failure_lines.join("\n")}
      MAIL
    end
  end
end
