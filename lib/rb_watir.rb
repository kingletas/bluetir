module Bluetir

  require 'watir'
  require 'test/unit'
  require 'thread'
  require 'fileutils'
  require File.expand_path("../bluetir/helper", __FILE__)

  class Bluetir_TestSuite < Test::Unit::TestCase
    #setups the unit tests
    @screenshots = nil
    def setup
      begin
        @helper = Bluetir::Helper.new()
        app_config = @helper.get_yaml_data('config.yml')['app_config']
        @assertions =  @helper.get_yaml_data('assertions.yml')
        @custom_base_url = app_config['custom_base_url']
        @custom_number_of_users = app_config['custom_number_of_users']

        puts "[INFO] using [#{@custom_number_of_users}] users from the config file"
        puts "[INFO] using [#{@custom_base_url}] for the custom_base_url found in the config file"
        
        @browser = Watir::Browser.start @custom_base_url

        @helper.set_browser @browser
        @helper.set_custom_url @custom_base_url

        @assert_proc = Proc.new {|test, expected|
          #assert
          puts "Running test: [#{test}]"
          assert(@browser.text.include?(expected), expected + ' was not found' )
        }
      rescue Exception => e
        puts 'An exception occurred : ' + e.message
      end
      @screenshots = 'screenshots'
      make_dir @screenshots

    end
    #cleanup method
    def teardown
      @browser.close
    end
    #simple function to create directories
    def make_dir (dirname)
      begin
        unless File.exists?(dirname)
          puts "[add] making directory '#{dirname}'"
          FileUtils.mkdir(dirname)
        end
      rescue Exception => e
        puts "An error occurred when trying to create the directory '#{dirname}', exception found was: "+ e.message
        exit 1
      end
    end
    #threaded method to run multiple instances of watir at the same time - considered experimental & buggy right now
    def _test_threads
      m = Mutex.new 
      threads = []
      @custom_number_of_users.times do
        threads << Thread.new do
          m.synchronize {threaded_mage_checkout}
          threaded_mage_checkout
        end
      end
      threads.each {|x| x.join}
    end
    #test the site is working
    def _test_pages_available
      #execute this code x number of times
      @custom_number_of_users.times do |i|
        puts 'Running tests for user #'+i.to_s
       # assert_section nil
      end
    end
    #Tests the magento checkout as guest
    def test_mage_checkout
      #@custom_number_of_users.times do
        start_time = Time.now
        add_to_cart @helper.get_yaml_data
        get_a_shipping_quote
        @helper.proceed_to_checkout
      #  assert_section 'checkout'
        finalize_checkout_as_guest
        final_time = Time.now - start_time
        puts "It took #{final_time} seconds to complete the order"
      #end
    end
    #Tests the magento checkout as guest - works with the threaded_test method
    def _threaded_mage_checkout
      @custom_number_of_users.times do
        start_time = Time.now
        add_to_cart @helper.get_yaml_data
        get_a_shipping_quote
        @helper.proceed_to_checkout
       # assert_section 'checkout'
        finalize_checkout_as_guest
        final_time = Time.now - start_time
        puts "It took #{final_time} seconds to complete the order"
      end
    end
    #asserts the browser contains a certain text
    def assert_section (selected)
      is_nil = selected === nil
      @assertions.each do |section,tests|
        now = Time.now
        if section === selected or is_nil then
          puts 'Testing ' + section
          tests.each do |test|
            @browser.goto(test[:url]) if is_nil
            #ensure the directory exists to save the screenshots
            make_dir "#{@screenshots}/#{section}"
            @browser.screenshot.save "screenshots/#{section}/screenshot-#{section}-#{now}.png"
            custom_assertion test[:tests]
          end
        end
      end
    end
    #reads the data.yml file and adds products to the cart - it reads the assertions.yml to assert the cart after each product is added
    def add_to_cart (data)
      added = false
      data.each do |product_data|
        products = product_data[:product]
        if products != nil
          @browser.goto(@custom_base_url + products[:url])
          products[:attributes].each do |attribute|
            @browser.select_list(attribute[:identifier],attribute[:element]).select attribute[:select] if attribute[:select]
            @browser.radio(attribute[:identifier],attribute[:element]).set  if attribute[:radio]
            @browser.text_field(attribute[:identifier],attribute[:element]).set attribute[:text] if attribute[:text]
          end
          #add the qty to the json data
          @browser.text_field(:id, "qty").set '3'
          @helper.custom_click_button :title, 'Add to Cart'
        #  assert_section 'cart'
          #cart tests 
          added = true
        end
      end
      exit 1 if !added
    end

    # todo Luis to implement
    def rb_add_to_cart (data) 
      # self.add_to_cart(data)
      # go to personalize tabs (href #contentPersonalize-tab)
        # select Message Type id: s7_ea1_message_type, monogram
        # Populate First Name Innital id:s7_ea1_mon_0
        # Populate Last Name Initial id: s7_ea1_mon_1
        # Populate Middle Initial id:s7_ea1_mon_2
        # Choose font selector id:s7_ea1_mon_font
        # Click alternate Add to Cart, id:s7_add_to_cart
    end
    
    #asserts every page contains the correct data
    def custom_assertion (custom_data)
      #  make sure Summary of Changes exists
      custom_data.each(&@assert_proc)
    end
    #finishes the checkout as guest
    def finalize_checkout_as_guest
      #@todo replace the sleep 4 with a custom wait (like until elemenet visible)

      @helper.fill_guest_customer
      @helper.fill_billing_information
      sleep 4
      @helper.fill_shipping_method_information
      sleep 4
      @helper.fill_payment_information
      sleep 4
      place_order
    end
    #gets and selects a shipping quote, reads the cart_shipping.yml file to get the information
    def get_a_shipping_quote
      @helper.get_yaml_data('cart_shipping.yml')['shipping_quote'].each do |element, value|
        puts  '==> Selecting value for ' + element
        @browser.text_field(value[:identifier],value[:element]).set value[:text] if value[:text]
        @browser.select_list(value[:identifier],value[:element]).select value[:select] if value[:select]
      end

      @helper.custom_click_button :title, 'Get a Quote'
     # assert_section 'cart_shipping'
      @browser.radio(:id,'s_method_ups_GND').set
      @helper.custom_click_button :title, 'Update Total'
    end
    #place order - moved from the helper because it has asserts the continue shopping button in the success page
    def place_order
      @browser.div(:id, "checkout-step-review").button(:text, "Place Order").click
      seconds = 0.10
      until @browser.text.include?("Your order has been received")  do
        sleep 0.10
        seconds += 0.5
      end
      puts "I waited #{seconds} seconds"
      #final code dependant assertion
      assert(@browser.button(:title,'Continue Shopping').enabled?)
    #  assert_section 'success'
    end
  end
end