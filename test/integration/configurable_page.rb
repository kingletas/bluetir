# frozen_string_literal: true

# A configurable product whose size and colour are Luma swatches, refusing the add until both are chosen.
#
# The markup copies Luma's swatch renderer: no <select>, one div per option carrying its label.
module ConfigurablePage
  SIZES = %w[XS S M L XL].freeze
  COLOURS = %w[Blue Purple Yellow].freeze

  SCRIPT = <<~JS
    function choose(option) {
      var attribute = option.closest('.swatch-attribute');
      attribute.querySelectorAll('.swatch-option').forEach(function (o) { o.classList.remove('selected'); });
      option.classList.add('selected');
      attribute.querySelector('.swatch-input').value = option.dataset.optionLabel;
    }
    function addToCart() {
      var inputs = Array.from(document.querySelectorAll('.swatch-input'));
      var chosen = inputs.every(function (input) { return input.value; });
      document.getElementById(chosen ? 'added' : 'required').style.display = 'block';
    }
  JS

  module_function

  def html
    <<~HTML
      <html><body>
        <h1>A Configurable Product</h1>
        <div class="swatch-opt">
          #{swatch_attribute('size', SIZES, 'text')}
          #{swatch_attribute('color', COLOURS, 'color')}
        </div>
        <input id="qty" value="1">
        <div id="required" class="mage-error" style="display:none">This is a required field.</div>
        <button id="product-addtocart-button" onclick="addToCart()">Add to Cart</button>
        <div id="added" class="message-success" style="display:none">
          You added A Configurable Product to your shopping cart
        </div>
        <script>#{SCRIPT}</script>
      </body></html>
    HTML
  end

  def swatch_attribute(code, labels, kind)
    <<~HTML
      <div class="swatch-attribute #{code} required" data-attribute-code="#{code}">
        <div class="swatch-attribute-options" role="listbox">#{labels.map { |l| option(l, kind) }.join}</div>
        <input class="swatch-input super-attribute-select" type="hidden" value="">
      </div>
    HTML
  end

  # A colour swatch has no text and takes its size from Luma's stylesheet, so it is sized inline here.
  def option(label, kind)
    text = kind == 'text' ? label : ''
    %(<div class="swatch-option #{kind}" data-option-label="#{label}" aria-label="#{label}" role="option" ) +
      %(style="display:inline-block; min-width:30px; height:20px" onclick="choose(this)">#{text}</div>)
  end
end
