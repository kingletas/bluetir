module Bluetir

require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'
require 'fileutils'


class Parse

  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }

  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.url = 'http://demo.magentocommerce.com/'
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($0)} -u 5 -p product.json -c customer.json"

      opts.separator ""
      opts.separator "Specific options:"

	  opts.on("-b", "--base-url BASEURL", "Base url to use") do |b|
	    options.url = b
	  end
	      
	  opts.on("-u", "--users USERS", "Amount of users to use") do |u|
	    options.users = u
	  end
	  opts.on("-p", "--product-file FILE", "file to use for the product data") do |p|
	    options.product_file = p
	  end
	  opts.on("-c", "--customer-file FILE", "file to use for the customer data") do |c|
	    options.customer_file = c
	  end
      opts.separator ""
      opts.separator "Common options:"

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      # Another typical switch to print the version.
      opts.on_tail("--version", "Show version") do
        puts Bluetir::VERSION
        exit
      end
    end
  begin
    opts.parse!(ARGV)
    options
  rescue OptionParser::ParseError => e
    warn e.message
    puts opts
    exit 1
  end
  end  # parse()

end  # class Parse

end