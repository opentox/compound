SERVICE = "compound"
require 'bundler'
Bundler.require
require './application.rb'
run OpenTox::Application
