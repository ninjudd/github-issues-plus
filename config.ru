$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'rubygems'
require 'bundler/setup'
require 'app'

App.set :root, File.realpath(File.dirname(__FILE__))
App.set :client_id, ENV['client_id']
App.set :client_secret, ENV['client_secret']

require 'data_mapper'
require 'hook'

DataMapper.setup(:default, "sqlite://#{App.root}/project.db")
DataMapper.finalize
DataMapper.auto_upgrade!

run App
