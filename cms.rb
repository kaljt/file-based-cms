require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'


#set :app_file, "./"
enable :sessions
set :session_secret, "saywhat"

#ENV["RACK_ENV"] = "development"

helpers do
  def dir_list(path)
    @file_list = []
    Dir.entries(path).each { |filename| @file_list << filename if !File.directory?(filename) }
    @file_list.sort
  end
  
  def user_logged?
    session[:signed_in] == true
  end
  
  def display_user
    session[:username]
  end
  
end

before do
  session[:signed_in] || false
end

def authorized_user?
  if user_logged?
    return
  else
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def valid_user?
  user_hash = YAML.load(File.read("#{auth_path}"))
  if BCrypt::Password.valid_hash?(user_hash.fetch(params[:username].to_sym, nil))
    return BCrypt::Password.new(user_hash.fetch(params[:username].to_sym)) == params[:password]
  else
    return false
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)  
end

def load_file_content(path)
  content = File.read(path)
  ext = File.extname(path)
  case ext
  when '.txt'
    headers["Content-Type"] = 'text/plain'
    content
  when '.md'
    erb render_markdown(content)
  end  
end

def auth_path
  if ENV["RACK_ENV"] == 'test'
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def data_path
  if ENV["RACK_ENV"] == 'test'
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :main_page
end

get '/stuff/:title/comments/:title' do
  session[:message] = "params[title] is #{params[:title]}"
  erb :main_page
end

get '/users/signin' do
  
  erb :signin
end

post '/signin' do
  if valid_user?
    #params[:username] == 'admin' && params[:password] == 'secret'
    session[:username] = params[:username]
    session[:signed_in] = true
    session[:message] = "Welcome!"
    redirect '/'
  else
    session[:message] = "Invalid Credentials."
    status 422
    erb :signin
  end
end

post '/signout' do
  session.delete(:username)
  session[:signed_in] = false
  session[:message] = 'You have been signed out.'
  redirect '/'
end

get '/new' do
  authorized_user?
  
  erb :create
end

post '/create' do
  authorized_user?
  
  @file_name = params[:filename].to_s.strip || ""
  file_path = File.join(data_path, @file_name)
  #puts "@file_name is #{@file_name}"

  if @file_name.empty? || !@file_name.match(/\w+[.](txt|md)/)
    session[:message] = "A name is required"
    #puts 'in first if statement'
    status 422
    erb :create
  elsif File.exist?(file_path)
    #puts 'in elsif statement'
    session[:message] = "#{@file_name} already exists!"
    erb :create
  else
    #puts 'in else statement'
    File.new(file_path, File::CREAT|File::TRUNC|File::RDWR)
    session[:message] = "#{@file_name} has been created."
    redirect '/'
  end
  
end

post '/delete' do
  authorized_user?
  
  file_name = params[:file_to_delete]
  file_path = File.join(data_path, file_name)
  if File.delete(file_path)
    session[:message] = "#{file_name} has been deleted."
    redirect '/'
  end
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  authorized_user?
  
  file_path = File.join(data_path, params[:filename])
  @file_name = params[:filename]
  @file_content = File.read(file_path)
  erb :edit_file
end

post '/:filename/edit' do
  authorized_user?
  
  @file_name = params[:filename]
  File.write("#{data_path}/#{@file_name}",params[:contents])
  
  session[:message] = "#{@file_name} has been updated."
  redirect '/'
end

