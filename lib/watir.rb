module Bluetir
  require 'rubygems'
  require 'watir'
  require 'test/unit'
  require 'thread'
  require 'fileutils'
  require 'net/smtp'
  require File.expand_path("../bluetir/helper", __FILE__)

  class Bluetir_TestSuite < Test::Unit::TestCase
    #setups the unit tests
    @screenshots = nil
    @send_email = true

    def setup
      puts "Running test...."
      begin
        @helper = Bluetir::Helper.new()

        @application = @helper.get_yaml_data('application.yml')
        puts @application['config']
        @app_config = @helper.get_yaml_data(@application['config'])['app_config']

        @helper.build_checkout_data(@application['checkout'])

        ##build the assertions file
        #@assertions = []
        # read the directory
        #Dir.glob('../../../etc/*.yml').each do|f|
         # @assertions = @assertions.zip(
         #                           @helper.get_yaml_data(f)
         #                 ).flatten.compact 
        #end
        
        ##end building the assertions

        @assertions =  @helper.get_yaml_data(@application['assertions'])
        @custom_base_url = @app_config['custom_base_url']
        @custom_number_of_users = @app_config['custom_number_of_users']

        if !@app_config['emails']  
          @email = 'doug.hatcher@blueacorn.com' 
        else 
          @email = @app_config['emails']
        end
      
        @send_email = @app_config['allow_email'] if @app_config['allow_email']

        puts "[INFO] using [#{@custom_number_of_users}] users from the config file"
        puts "[INFO] using [#{@custom_base_url}] for the custom_base_url found in the config file"
        
        @browser = Watir::Browser.start @custom_base_url

        @helper.set_browser @browser
        @helper.set_custom_url @custom_base_url

        @assert_proc = Proc.new {|test, expected|
          #assert
          puts "[INFO] Running test: [#{test}]"
          assert(@browser.text.include?(expected), expected + ' was not found' )
        }
      rescue Exception => e
        puts 'An exception occurred : ' + e.message
        send_email(@email, :body=>'An exception occured.' + e.message)
      end
      @screenshots = @app_config['screenshots_dir']
      make_dir @screenshots

    end
    #cleanup method
    def teardown
      puts "[INFO] Tearing down the house..."# we don't know if we completed successfully
      send_email(@email, :body=>'completed successfully')
      #if ! to_boolean(@app_config['debug']) || to_boolean(@app_config['close_on_error']) then
        @browser.close
      #end
     
    end
    #simple function to create directories
    def make_dir (dirname)
      puts "[INFO] Checking for the screenshots directory: [#{dirname}]"
      begin
        unless File.exists?(dirname)
          puts "[add] making directory '#{dirname}'"
          FileUtils.mkdir(dirname)
        end
      rescue Exception => e
        puts "[INFO] An error occurred when trying to create the directory '#{dirname}', exception found was: "+ e.message
        exit 1
      end
    end
    #test the site is working
    def _test_pages_available
      #execute this code x number of times
      @custom_number_of_users.times do |i|
        puts '[INFO] Running tests for user #'+i.to_s
        assert_section nil
      end
    end
    #Tests the magento checkout as guest
    def test_mage_checkout
      @custom_number_of_users.times do |i|
        puts '[INFO] Checking out as guest... Running test for user #'+i.to_s
        start_time = Time.now
        add_to_cart @helper.get_yaml_data @application['data']
        get_a_shipping_quote
        @helper.proceed_to_checkout
        assert_section 'checkout'
        finalize_checkout_as_guest
        final_time = Time.now - start_time
        puts "[INFO] It took #{final_time} seconds to complete the order"
      end
    end
        #Tests the magento checkout as guest
    def test_mage_checkout_register
      @custom_number_of_users.times do |i|
        puts '[INFO] Checking out as a customer... Running test for user #'+i.to_s
        start_time = Time.now
        add_to_cart @helper.get_yaml_data @application['data']
        get_a_shipping_quote
        @helper.proceed_to_checkout
        assert_section 'checkout'
        finalize_checkout_as_customer
        final_time = Time.now - start_time
        puts "[INFO] It took #{final_time} seconds to complete the order"
      end
    end
    #asserts the browser contains a certain text
    def assert_section (selected)
      is_nil = selected === nil
      @assertions.each do |section,tests|
        now = Time.now
        if section === selected or is_nil then
          puts '[INFO] Testing ' + section
          tests.each do |test|
            url = "#{@custom_base_url}#{test[:url]}"
            @browser.goto(url) if is_nil
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
          url = products[:url]
          puts "[INFO] Working with Product: [#{url}]"
          @browser.goto(@custom_base_url + url)
          assert_section 'product'
          products[:attributes].each do |attribute|
            @browser.select_list(attribute[:identifier],attribute[:element]).select attribute[:select] if attribute[:select]
            @browser.radio(attribute[:identifier],attribute[:element]).set  if attribute[:radio]
            @browser.text_field(attribute[:identifier],attribute[:element]).set attribute[:text] if attribute[:text]
            @browser.checkbox(attribute[:identifier],attribute[:element]).set attribute[:checkbox] if attribute[:checkbox] # checkbox support
            @browser.button(:class=>attribute[:class]).click if attribute[:click] and attribute[:class]
            sleep attribute[:delay] if attribute[:delay] # because timing is important sometimes
          end
          #add the qty to the json data
          products[:qty] = '3' if !products[:qty] # custom qty support
          @browser.text_field(:id, "qty").set products[:qty]
          @helper.custom_click_button :title, 'Add to Cart'
          assert_section 'cart'
          #cart tests
          added = true
        end
      end
      exit 1 if !added
    end
    #asserts every page contains the correct data
    def custom_assertion (custom_data)
      #  make sure Summary of Changes exists
      #puts "[INFO] assertions enabled? [#{@app_config['enable_assertions']}]"
       puts "[INFO] Running assertions now"
      #custom_data.each(&@assert_proc) #if @app_config['enable_assertions']
    end
    #finishes the checkout as guest
    def finalize_checkout_as_guest
      #@todo replace the sleep 4 with a custom wait (like until elemenet visible)
      @helper.fill_guest_customer
      @helper.fill_billing_information
      checkout_common    end
    #finishes the checkout as a customer
    def finalize_checkout_as_customer
      #@todo replace the sleep 4 with a custom wait (like until elemenet visible)
      @helper.fill_customer
      @helper.fill_billing_information true # true indicates it needs to use the billing_register section
      checkout_common
    end
    def checkout_common
      sleep 4
      @helper.fill_shipping_method_information
      sleep 4
      @helper.fill_payment_information
      sleep 4
      place_order
    end
    #gets and selects a shipping quote, reads the cart_shipping.yml file to get the information
    def get_a_shipping_quote
      shipping = @helper.get_yaml_data(@application['cart_shipping'])
      shipping['shipping_quote'].each do |element, value|
        puts  '[INFO] ==> Selecting value for ' + element
        @browser.text_field(value[:identifier],value[:element]).set value[:text] if value[:text]
        @browser.select_list(value[:identifier],value[:element]).select value[:select] if value[:select]
      end

      get_a_quote = 'Get a Quote'

      [:text,:title].each do |sym|
        @helper.custom_click_button sym, get_a_quote if @browser.button(sym,get_a_quote).exists?
      end      
     
      assert_section 'cart_shipping'
      shipping['shipping_method'].each do |name,shipping_method_id|
        puts "[INFO] Trying to select the shipping method [#{name}]"
        if @browser.radio(:id,shipping_method_id).exists? then

            @browser.radio(:id,shipping_method_id).set
            break
        end       
      end

      
      @helper.custom_click_button :text, 'Update Total'
    end
    #place order - moved from the helper because it has asserts the continue shopping button in the success page
    def place_order
      @browser.div(:id, "checkout-step-review").button(:text, "Place Order").click
      seconds = 0.10
      until @browser.text.include?("Your order has been received")  do
        sleep 0.10
        seconds += 0.5
      end
      puts "[INFO] I waited #{seconds} seconds"
      #final code dependant assertion
      assert(@browser.button(:title,'Continue Shopping').enabled?)
      assert_section 'success'
    end

    def to_boolean(str)
      return str === true
    end

    ##
    # Sends email to one or many users
    #
    def send_email(to,opts={})

      if to_boolean(@send_email)
           opts[:server]      ||= 'localhost'
           opts[:from]        ||= 'noreply@bluetir'
           opts[:from_alias]  ||= 'Bluetir Script'
           opts[:subject]     ||= 'Notification'
           opts[:body]        ||= ''
     
           msg = <<END_OF_MESSAGE
                 From: #{opts[:from_alias]} <#{opts[:from]}>
                 To: <#{to}>
                 Subject: #{opts[:subject]}
     
                 #{opts[:body]}
                 Testing with enabled
END_OF_MESSAGE
     

          Net::SMTP.start(opts[:server]) do |smtp|
            smtp.send_message msg, opts[:from], to
          end
      end
    end
  end
end