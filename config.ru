$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'rubygems'
require 'bundler/setup'
require 'app'

App.set :root, File.dirname(__FILE__)

require 'data_mapper'
require 'hook'

DataMapper.setup(:default, "sqlite://#{App.root}/project.db")
DataMapper.finalize
DataMapper.auto_upgrade!

run App
