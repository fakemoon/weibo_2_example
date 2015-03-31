# encoding: utf-8

require 'rubygems'
require 'bundler'
Bundler.require

enable :sessions

WeiboOAuth2::Config.api_key = ENV['KEY']
WeiboOAuth2::Config.api_secret = ENV['SECRET']
WeiboOAuth2::Config.redirect_uri = ENV['REDIR_URI']

$userlist = {}
$statuslist = {}
configure do
  set :bind => "0.0.0.0", :port => "80"
end

get '/' do
  client = WeiboOAuth2::Client.new
  if session[:access_token] && !client.authorized?
    token = client.get_token_from_hash({:access_token => session[:access_token], :expires_at => session[:expires_at]}) 
    p "*" * 80 + "validated"
    p token.inspect
    p token.validated?
    
    unless token.validated?
      reset_session
      redirect '/connect'
      return
    end
  end
  if session[:uid]
    @user = client.users.show_by_uid(session[:uid]) 
    @statuses = client.statuses
    $userlist[@user.screen_name] = session[:uid]
    $statuslist[session[:uid]] = @statuses.user_timeline({:count => 100}).statuses.clone
  end
  haml :index
end

get '/connect' do
  client = WeiboOAuth2::Client.new
  redirect client.authorize_url
end

get '/callback' do
  client = WeiboOAuth2::Client.new
  access_token = client.auth_code.get_token(params[:code].to_s)
  session[:uid] = access_token.params["uid"]
  session[:access_token] = access_token.token
  session[:expires_at] = access_token.expires_at
  p "*" * 80 + "callback"
  p access_token.inspect
  @user = client.users.show_by_uid(session[:uid].to_i)
  redirect '/'
end

get '/logout' do
  reset_session
  redirect '/'
end 

get '/screen.css' do
  content_type 'text/css'
  sass :screen
end

get '/users' do
  "#{$userlist.to_json}"
end

get '/posts/:uid' do |uid|
  status_temp = {}
  unless params['keywords'] do
    $statuslist[uid].each_with_index do |stat, i|
      status_temp[i] = stat[:text]
    end
    "#{status_temp.to_json}"
  else
    keywords = params['keywords'].to_s.split(',')
    $statuslist[uid].each_with_index do |stat, i|
      response = open("http://api.yutao.us/api/keyword/#{stat[:text]}").read.to_s.split(',')
      hit = true
      keywords.each do |item|
        hit = false unless response.Include?(item)
      end
      if hit do
        status_temp[i] = stat[:text]
      end
    end
  end
  "#{status_temp.to_json}"
end

post '/update' do
  client = WeiboOAuth2::Client.new
  client.get_token_from_hash({:access_token => session[:access_token], :expires_at => session[:expires_at]}) 
  statuses = client.statuses

  unless params[:file] && (pic = params[:file].delete(:tempfile))
    statuses.update(params[:status])
  else
    status = params[:status] || '图片'
    statuses.upload(status, pic, params[:file])
  end

  redirect '/'
end

helpers do 
  def reset_session
    session[:uid] = nil
    session[:access_token] = nil
    session[:expires_at] = nil
  end
end
