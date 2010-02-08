#! /usr/local/bin/ruby-1.9

require 'rubygems'

require 'amalgalite'

require 'sinatra'
require 'ceres/api'

enable :sessions

class Demeter
  @datadump = Amalgalite::Database.new(File.dirname(__FILE__) + "/db/dom111-sqlite3-v1.db")
  @cached_until = Hash.new { Time.at(0) }
  @active_starbases, @starbases = [], {}
  
  File.open(File.dirname(__FILE__) + "/config/demeter") do |f|
    @title = f.gets
    @user_id, @api_key, @character_id = f.gets.split(" ")
    @username, @password = f.gets.split(" ")
  end
  
  @api = Ceres::API.new(:user_id => @user_id.to_i, :api_key => @api_key, :character_id => @character_id)
  
  def self.datadump
    @datadump
  end
  
  def self.cached_until(key)
    @cached_until[key]
  end
  
  def self.set_cached_until(key, value)
    @cached_until[key] = value
  end
  
  def self.active_starbases
    @active_starbases
  end
  
  def self.active_starbases=(array)
    @active_starbases = array
  end
  
  def self.starbase(key)
    @starbases[key]
  end
  
  def self.merge_starbase(key, values)
    @starbases[key] || @starbases[key] = {}
    @starbases[key] = @starbases[key].merge(values)
  end
  
  def self.api
    @api
  end
  
  def self.title
    @title
  end
  
  def self.username
    @username
  end
  
  def self.password
    @password
  end
end

def authorize(username, password)
  if [username, password] == [Demeter.username, Demeter.password]
    session[:user] = username
    puts "Test: #{Demeter.username} == #{username} & #{Demeter.password} == #{password} & #{session[:user]}"
  end
end

def authorized?
  session[:user]
end


get '/' do
  redirect '/login' unless authorized?
  
  @starbases = Demeter.active_starbases.map { |x| Demeter.starbase(x) }
  
  erb :index
end

get '/login' do
  erb :login
end

get '/logout' do
  session[:user] = nil
  redirect '/login'
end

post '/login' do
  authorize(params[:username], params[:password])
  
  if authorized?
    redirect '/'
  else
    redirect '/login'
  end
end

get '/update' do
  redirect '/login' unless authorized?
  
  if Demeter.cached_until(:list) < Time.now
    active_starbases, cached_until = Demeter.api.starbases
    active_starbases.each { |x| Demeter.merge_starbase(x[:id], x) }    
    
    Demeter.active_starbases = active_starbases.map { |x| x[:id] }
    Demeter.set_cached_until(:list, cached_until)
    
    redirect '/'
  else
    status 403
    "403: CCP Servers do not have an updated starbase list yet"
  end
end

get '/update/:id' do
  redirect '/login' unless authorized?
  
  id = params[:id].to_i
  
  if Demeter.active_starbases.include?(id) && Demeter.cached_until(id) < Time.now
    starbase, cached_until = Demeter.api.starbase(id)
    
    Demeter.merge_starbase(id, starbase)
    Demeter.set_cached_until(id, cached_until)
    
    redirect '/'
  else
    status 403
    "403: CCP Servers do not have updated information for starbase #{id} yet"
  end
end