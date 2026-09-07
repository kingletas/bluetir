# frozen_string_literal: true

require_relative 'step'

module Bluetir
  module Flows
    # Puts one product in the cart and proves the store said so.
    class AddToCart < Step
      DEFAULT_QUANTITY = 1

      # Adds +product+ and returns whether the store confirmed it.
      def call(product)
        goto(product['url'])
        assertions.verify(browser, 'product', result)
        choose_options(product['options'])
        enter_quantity(product['qty'])
        expect('cart', "added #{product['url']} to the cart") do
          click(field('add_to_cart_button'))
          confirmed? || confirmed_at_the_cart?(product)
        end
      end

      private

      def choose_options(options)
        Array(options).each_with_index do |definition, index|
          selector = Selector.new("option #{index + 1}", definition)
          apply(Field.new(browser, selector), definition)
        end
      end

      def apply(field, definition)
        value = definition['select'] || definition['set'] || definition['text']
        value ? field.fill(value) : field.click
        sleep(definition['delay']) if definition['delay']
      end

      def enter_quantity(quantity)
        quantity_field = optional_field('quantity_field')
        return unless quantity_field&.present?

        quantity_field.fill(quantity || DEFAULT_QUANTITY)
      end

      def confirmed?
        confirmation = optional_field('add_to_cart_confirmation')
        return wait_until? { confirmation.present? } if confirmation

        wait_until? { page_says?(storefront.text('add_to_cart_confirmation')) }
      rescue Watir::Wait::TimeoutError
        false
      end

      # The second way a store can accept an add.
      #
      # Hyvä intercepts the form with Alpine and shows a message on the page —
      # unless Alpine has not bound it yet, in which case the browser submits
      # the form and navigates away, and there is no message to wait for. That
      # is still an add, so it is confirmed where the evidence actually is: the
      # cart should now mention the product.
      #
      # A Magento url key is the product name slugified, which is what makes
      # this checkable without asking a profile for anything more.
      def confirmed_at_the_cart?(product)
        goto(storefront.path('cart'))
        page_says?(name_from(product['url']))
      end

      def name_from(url)
        url.to_s.split('/').last.to_s.sub(/\.html\z/, '').tr('-_', '  ')
      end
    end
  end
end
