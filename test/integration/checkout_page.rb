# frozen_string_literal: true

# The fixture store's checkout: shipping, payment and the success message Place Order reveals.
#
# The markup copies the ids and names Magento 2 Luma uses. The confirmation text is in FixtureStore.
module CheckoutPage
  # Drawn over the button until it takes its place, so a click in that window lands on the address every time.
  SETTLING_SCRIPT = <<~JS
    function showPayment(settlesAfter) {
      var address = document.querySelector('.billing-address-details');
      document.getElementById('checkmo-method').style.display = 'block';
      if (settlesAfter >= 0) {
        setTimeout(function () { address.style.position = 'static'; }, settlesAfter);
      }
    }
  JS

  module_function

  def html
    <<~HTML
      <html><body>
        #{shipping_step}
        <input type="radio" id="checkmo" name="payment">
        <div class="payment-method _active">
          <button class="action checkout" onclick="
            document.getElementById('done').style.display='block'">Place Order</button>
        </div>
        #{success_block}
      </body></html>
    HTML
  end

  # A payment step that appears on Next with its billing address still rendering, the way Luma's does:
  # the address sits above Place Order and pushes it down. A negative +settles_after_ms+ never settles.
  def settling(settles_after_ms:)
    <<~HTML
      <html><body>
        #{shipping_step}
        <div class="payment-method _active" id="checkmo-method" style="display:none">
          <input type="radio" id="checkmo" name="payment" checked>
          <div class="payment-method-content" style="position:relative">
            #{billing_address}
            <div class="actions-toolbar">
              <button class="action primary checkout" title="Place Order" onclick="
                document.getElementById('done').style.display='block'">Place Order</button>
            </div>
          </div>
        </div>
        #{success_block}
        <script>
          #{SETTLING_SCRIPT}
          document.querySelector("[data-role='opc-continue']").onclick = function () {
            showPayment(#{Integer(settles_after_ms)});
          };
        </script>
      </body></html>
    HTML
  end

  def shipping_step
    <<~HTML
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
    HTML
  end

  def billing_address
    <<~HTML
      <div class="billing-address-details" style="position:absolute; top:0; left:0; width:400px; background:#fff">
        Test Order<br>1 Test Street<br>Austin, Texas 78701<br>United States<br>5125550100
      </div>
    HTML
  end

  def success_block
    <<~HTML
      <div id="done" class="checkout-success" style="display:none">
        <h1>#{FixtureStore::SUCCESS_TEXT}</h1>
        #{FixtureStore::GUEST_ORDER_NUMBER}
        #{FixtureStore::ORDER_EMAIL}
      </div>
    HTML
  end
end
