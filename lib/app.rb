require 'sinatra'
require 'json'
require 'helpers'
require 'github/repo'

class App < Sinatra::Base
  enable :sessions

  include Helpers

  get '/issues/:user/:repo' do
    if token = session[:token]
      @repo = Github::Repo.new(token, params)
      erb :index
    else
      url = github.build_url("/login/oauth/authorize", {
        :client_id => ENV['client_id'],
        :scope     => 'repo',
        :state     => request.url,
      })
      redirect url.to_s
    end
  end

  get '/issues/authorize' do
    response = github.post("https://github.com/login/oauth/access_token",
      :client_id     => ENV['client_id'],
      :client_secret => ENV['client_secret'],
      :code          => params[:code],
      :state         => params[:state],
    )
    session[:token] = response.body['access_token']

    redirect params[:state]
  end
end
