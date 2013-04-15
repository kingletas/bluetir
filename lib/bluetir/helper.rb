module Bluetir
  require 'yaml'
  class Helper
    @browser = nil
    @custom_base_url = nil
    @checkout_data = {}

    #initializes the class - important to get the checkout data
    def initialize
      @checkout_data = []
    end

    #initializes the class - important to get the checkout data
    def build_checkout_data (checkout_file)
      @checkout_data = get_yaml_data(checkout_file)
    end


    #clicks a button if it is visible and enabled
    def custom_click_button(identifier, value)
      button =  @browser.button(identifier,value)
      button.click if button.enabled? and button.visible?
    end
    #fires multiple events for a given element
    #@todo move the events to a configuration file
    def custom_fire_events (element)
      ['onclick', 'onmouseover','onchange','onmousedown','onfocus','onblur'].each do |event|
        element.fire_event event
      end
    end

    #Clicks the proceed to checkout button
    def proceed_to_checkout
      custom_click_button :title, 'Proceed to Checkout'
    end
    #sets the browser to be used in the helper
    def set_browser(browser)
      @browser = browser
    end
    #sets the custom_base_url
    #@todo normalize the use of the custom_base_Url, currently it is not being used everywhere
    def set_custom_url(custom_base_url)
      @custom_base_url = custom_base_url
    end
    #future implementation to place an order as a customer
    def finalize_checkout_as_customer
    end
    #selects the guest option
    def fill_guest_customer
      @browser.radio(:id, "login:guest").set
      @browser.div(:id, "checkout-step-login").button(:text, "Continue").click
    end
        #selects the guest option
    def fill_customer
      @browser.radio(:id, "login:register").set
      @browser.div(:id, "checkout-step-login").button(:text, "Continue").click
    end
    #fills the billing information read from the checkout.yml - currently using billing to ship as well
    def fill_billing_information (register = false)
      #billing-please-wait
      selects = ['region_id', 'country_id']
      radios = ['use_for_shipping_yes']
      @checkout_data['billing'].each do |identifier, value|
        #if i am registering ensure we are using a new email account
        if register && identifier == 'email' then
          timestamp = Time.now.to_i
          value = value.gsub('@',"#{timestamp}@")
        end

        if identifier == 'use_for_shipping_yes' then
          @browser.div(:id, "checkout-step-billing").radio(:id, "billing:#{identifier}").set
        elsif !selects.include? identifier and !radios.include? identifier then
          @browser.text_field(:id, "billing:#{identifier}").set(value)
        elsif !radios.include? identifier then
          @browser.select_list(:id, "billing:#{identifier}").select(value)
        end
      end
      if (register) then
        @checkout_data['billing_register'].each do |identifier, value|
            @browser.text_field(:id, "billing:#{identifier}").set(value)
        end
      end
      @browser.div(:id, "checkout-step-billing").button(:text, 'Continue').click
    end

    #fills the payment information read from the checkout.yml
    def fill_payment_information
      @browser.radio(:id, @checkout_data['payment']['method']).set
      @browser.div(:id, "checkout-step-payment").button(:text, @checkout_data['payment']['text']).click
    end
    #fills the shipping method information read from the checkout.yml
    def fill_shipping_method_information
      @browser.radio(:id, @checkout_data['shipping_method']['method']).set
      @browser.div(:id, "checkout-step-shipping_method").button(:text, @checkout_data['shipping_method']['text']).click
    end
    #method to wait for a element to appear in the page
    def custom_wait_checkout (id)
      begin
        button = @browser.div(:id, "checkout-step-#{id}").button(:title, "Continue")
        until !button.visible? do
            sleep 0.10
        end
        rescue
          custom_wait_checkout id
      end
    end
    #loads the yaml file as an object
    def get_yaml_data (filename)
      puts "[INFO] Attempting to read this file: [#{filename}]"
      path = '../../../etc/'
      file = File.expand_path("#{path}#{filename}", __FILE__)
      puts "[INFO] File [#{file}] exists? #{File.exists?(file)}" 
      if File.exists?(file) then
        begin
          return   YAML.load_file(file)
        rescue Exception => e
          puts "[INFO] File: '#{file}' not found in path: '#{path}'  Additionally this Exception was thrown:  #{e.message}"
          exit 1
        end
      else
        exit 1  
      end
    end

  end
end