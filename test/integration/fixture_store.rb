# frozen_string_literal: true

require 'tmpdir'
require 'pathname'
require_relative 'configurable_page'

# A four-page storefront written to disk, so a flow can be driven through a real browser.
#
# The markup copies the ids and names Magento 2 Luma uses, which is what makes this a
# test of the selectors and not only of the Ruby around them.
module FixtureStore
  SUCCESS_TEXT = 'Thank you for your purchase!'

  # Magento_Checkout's success.phtml: the order line depends on whether the shopper can view the order.
  GUEST_ORDER_NUMBER = '<p>Your order # is: <span>000000001</span>.</p>'
  CUSTOMER_ORDER_NUMBER = '<p>Your order number is: <a href="#" class="order-number">' \
                          '<strong>000000001</strong></a>.</p>'
  ORDER_EMAIL = '<p>We&#039;ll email you an order confirmation with details and tracking info.</p>'

  module_function

  def build(dir)
    root = Pathname.new(dir)
    root.join('product.html').write(product_page)
    root.join('configurable.html').write(ConfigurablePage.html)
    root.join('cart.html').write(cart_page)
    root.join('checkout.html').write(checkout_page)
    root.join('storefront.yml').write(profile)
    root
  end

  def product_page
    <<~HTML
      <html><body>
        <h1>A Product</h1>
        <p>In stock</p>
        <input id="qty" value="1">
        <button id="product-addtocart-button" onclick="
          document.getElementById('added').style.display='block'">Add to Cart</button>
        <div id="added" class="message-success" style="display:none">
          You added A Product to your shopping cart
        </div>
      </body></html>
    HTML
  end

  def cart_page
    <<~HTML
      <html><body>
        <h1>Shopping Cart</h1>
        <p>Estimate Shipping and Tax</p>
        <div id="shipping-zip-form">
          <select name="country_id"><option>United States</option><option>Canada</option></select>
          <select name="region_id"><option>Texas</option><option>Ohio</option></select>
          <input name="postcode">
        </div>
      </body></html>
    HTML
  end

  def checkout_page
    <<~HTML
      <html><body>
        <h1>Shipping Address</h1>
        <input id="customer-email">
        <div id="shipping-new-address-form">
          <input name="firstname"><input name="lastname"><input name="company">
          <input name="street[0]"><input name="city">
          <select name="region_id"><option>Texas</option></select>
          <input name="postcode">
          <select name="country_id"><option>United States</option></select>
          <input name="telephone">
        </div>
        <input type="radio" value="flatrate_flatrate" name="shipping">
        <button data-role="opc-continue">Next</button>
        <input type="radio" id="checkmo" name="payment">
        <div class="payment-method _active">
          <button class="action checkout" onclick="
            document.getElementById('done').style.display='block'">Place Order</button>
        </div>
        <div id="done" class="checkout-success" style="display:none">
          <h1>#{SUCCESS_TEXT}</h1>
          #{GUEST_ORDER_NUMBER}
          #{ORDER_EMAIL}
        </div>
      </body></html>
    HTML
  end

  def profile
    <<~YML
      name: Fixture store
      platform: magento2
      paths:
        cart: cart.html
        checkout: checkout.html
      texts:
        add_to_cart_confirmation: "to your shopping cart"
        order_success: "#{SUCCESS_TEXT}"
      selectors:
        add_to_cart_button:       { type: button,      id: product-addtocart-button }
        quantity_field:           { type: text_field,  id: qty }
        add_to_cart_confirmation: { type: div,         id: added }
        estimate_country:         { type: select_list, css: "#shipping-zip-form select[name='country_id']" }
        estimate_region:          { type: select_list, css: "#shipping-zip-form select[name='region_id']" }
        estimate_postcode:        { type: text_field,  css: "#shipping-zip-form input[name='postcode']" }
        checkout_email:           { type: text_field,  id: customer-email }
        address_firstname:        { type: text_field,  css: "#shipping-new-address-form input[name='firstname']" }
        address_lastname:         { type: text_field,  css: "#shipping-new-address-form input[name='lastname']" }
        address_street:           { type: text_field,  css: "#shipping-new-address-form input[name='street[0]']" }
        address_city:             { type: text_field,  css: "#shipping-new-address-form input[name='city']" }
        address_region:           { type: select_list, css: "#shipping-new-address-form select[name='region_id']" }
        address_postcode:         { type: text_field,  css: "#shipping-new-address-form input[name='postcode']" }
        address_country:          { type: select_list, css: "#shipping-new-address-form select[name='country_id']" }
        address_telephone:        { type: text_field,  css: "#shipping-new-address-form input[name='telephone']" }
        shipping_method:          { type: radio,       css: "input[value='flatrate_flatrate']" }
        shipping_continue_button: { type: button,      css: "button[data-role='opc-continue']" }
        payment_method:           { type: radio,       id: checkmo }
        place_order_button:       { type: button,      css: ".payment-method._active button.action.checkout" }
    YML
  end
end
