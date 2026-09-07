# frozen_string_literal: true

require_relative 'step'

module Bluetir
  module Flows
    # Walks the checkout as a guest and places the order.
    class Checkout < Step
      # How long to give the checkout before deciding it bounced rather than
      # merely being slow. The full timeout is kept for the second attempt.
      FIRST_LOOK = 20

      # Runs the whole checkout for +order+ and places it.
      def call(order)
        reach_the_last_step(order) && place_order
      end

      # Everything call does, stopping at the last button: it checks the button
      # is there and usable rather than clicking it. This is what an acceptance
      # run wants — proof the whole funnel works, with no order on anyone's
      # system. It is a second method rather than a flag, so no call site can
      # place an order by getting an argument wrong.
      def review(order)
        reach_the_last_step(order) && ready_to_place?
      end

      private

      def reach_the_last_step(order)
        goto(storefront.path('checkout'))
        return false unless reached_checkout?

        enter_contact(order)
        enter_address(order['address'])
        return false unless choose_shipping_method
        return false unless advance_to_payment

        return false unless choose_payment_method

        accept_terms
      end

      # Agrees to the store's terms where it has any.
      #
      # ScandiPWA keeps its place-order button disabled until "Agree to Terms &
      # Conditions" is ticked, so a checkout test cannot reach the last step
      # without it. A profile that declares no terms_agreement does nothing
      # here, and that is deliberately the operator's decision to configure
      # rather than something the tool assumes: agreeing to a shop's terms is a
      # choice a person makes about their own shop.
      #
      # A declared control that cannot be used FAILS. Skipping it because it is
      # not on the page would put a tick beside an agreement nobody made, and
      # then leave the real failure to surface two steps later as a disabled
      # button with no explanation.
      def accept_terms
        return true unless storefront.key?('terms_agreement')

        expect('checkout', 'the terms were agreed to') { field('terms_agreement').choose }
      end

      def reached_checkout?
        expect('checkout', 'the checkout page loaded') { arrived?(FIRST_LOOK) || waited_longer? }
      end

      def arrived?(timeout)
        browser.wait_until(timeout: timeout) { field('checkout_email').present? }
        true
      rescue Watir::Wait::TimeoutError
        false
      end

      # What to do when the checkout is not there after the first look.
      #
      # A browser somewhere else has bounced: a storefront that keeps its cart
      # in the browser can reach the checkout before the server has a quote to
      # check out, and the route sends it back to the cart. That is a race and
      # worth one more try.
      #
      # A browser on the right page is merely slow, and gets the rest of its
      # timeout. Giving up at FIRST_LOOK would make this step LESS patient than
      # the store was configured for, which is how a bounce retry turned into a
      # shorter wait for everybody who never bounced.
      def waited_longer?
        return_from_the_cart unless on_the_checkout?
        arrived?(Watir.default_timeout)
      end

      def on_the_checkout?
        browser.url.include?(storefront.path('checkout'))
      end

      def return_from_the_cart
        warn "[info] the checkout bounced to #{browser.url}, letting the cart catch up"
        goto(storefront.path('cart'))
        goto(storefront.path('checkout'))
      end

      def enter_contact(order)
        field('checkout_email').fill(unique_email(order['email']))
      end

      # Gives every run its own address, so a repeat run is not a duplicate
      # customer. An address that already carries a tag is left alone: a persona
      # generates its own, and stacking a second one buries whose order it was.
      def unique_email(email)
        text = email.to_s
        return text unless text.include?('@')
        return text if text.split('@').first.include?('+')

        text.sub('@', "+#{Time.now.to_i}@")
      end

      def enter_address(address)
        Array(address).each do |name, value|
          target = optional_field("address_#{name}")
          next warn("[warn] the profile has no selector for address field '#{name}'") unless target

          target.fill(value)
        end
      end

      def choose_shipping_method
        expect('checkout', 'a shipping method was available') do
          method = field('shipping_method')
          wait_until? { method.present? } && method.choose
        end
      end

      # A one-page checkout, Hyvä's among them, shows payment alongside shipping
      # and has no button to advance. A profile that declares none says so, and
      # the step becomes a wait rather than a click.
      #
      # What proves the payment step arrived is the place-order button, not a
      # payment radio: a store with a single payment method enabled renders no
      # radio at all, so waiting for one there waits for ever.
      def advance_to_payment
        expect('checkout', 'the checkout reached the payment step') do
          continue_button = optional_field('shipping_continue_button')
          click(continue_button) if continue_button
          wait_until? { field('place_order_button').present? }
        end
      end

      # Picks a payment method where there is a choice to make. One method
      # enabled means Magento has already chosen it and drawn no radio, and
      # nothing to choose is not a failure — the place-order button that the
      # next step checks is what says the payment step is really usable.
      def choose_payment_method
        expect('checkout', 'a payment method is selected') do
          method = optional_field('payment_method')
          next true unless method&.present?

          method.choose
        end
      end

      # Everything short of the commitment: the button exists, it is on screen,
      # and the store would accept a click. Never clicked.
      def ready_to_place?
        expect('checkout', 'the order is ready to place') do
          button = field('place_order_button')
          wait_until? { button.present? } && button.element.enabled?
        end
      end

      def place_order
        placed = expect('success', 'the order was placed') do
          field('place_order_button').click
          wait_until? { page_says?(storefront.text('order_success')) }
        end
        assertions.verify(browser, 'success', result) if placed
        placed
      end
    end
  end
end
