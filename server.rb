require 'rubygems'
require 'sinatra'
require 'sinatra/cookies'
require 'faraday'
require 'faraday_middleware'
require 'pp'

set :port, ARGV[0] || 8080

get '/issues/:user/:repo' do
  begin
    @repo = Repo.new(cookies[:token], params)
    erb :index
  rescue Repo::HttpError
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
    :state         => params[:state]
  )
  cookies[:token] = response.body['access_token']

  redirect params[:state]
end

def github
  @github ||= Faraday.new(:url => "https://github.com/", :headers => { :accept =>  'application/json'}) do |conn|
    conn.request :json
    conn.response :json
    conn.adapter Faraday.default_adapter
  end
end

class Repo
  class HttpError < Exception; end

  attr_reader :opts, :token

  def initialize(token, opts = {})
    @token = token
    @opts  = opts
  end

  def http_params
    params = {
      :state     => opts[:state],
      :labels    => opts[:labels],
      :milestone => milestone_number(opts[:milestone])
    }
    params.delete_if {|k,v| v.nil?}
    params
  end

  def issues
    http_get('issues', http_params.merge(:per_page  => 100))
  end

  def issues_by_assignee
    issues.group_by do |issue|
      issue['assignee']
    end.sort_by do |assignee, issues|
      -(assignee ? issues.count : 0)
    end
  end

  def url
    "https://api.github.com/repos/#{opts[:user]}/#{opts[:repo]}"
  end

  def html_url
    "https://github.com/#{opts[:user]}/#{opts[:repo]}"
  end

  def assigned_url(login)
    http.build_url("#{html_url}/issues/assigned/#{login}", http_params)
  end

  def http
    @http ||= Faraday.new(:url => url) do |conn|
      conn.request :oauth2, token
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  def http_get(path, params = {})
    response = http.get(path, params.merge(:per_page => 100))
    raise HttpError, response.body['message'] unless response.status == 200

    if next_link = link_header(:next, response.headers)
      rest = http_get(next_link)
      response.body + rest
    else
      response.body
    end
  end

  def link_header(rel, headers)
    if link_header = headers['link']
      link = link_header.split(',').detect do |link|
        link =~ /rel="#{rel}"/
      end
      link.scan(/<([^>]+)>/).first.first if link
    end
  end

  def milestone_number(title)
    return unless title

    [:open, :closed].each do |state|
      http_get('milestones', :state => state).each do |milestone|
        return milestone['number'] if milestone['title'] == title
      end
    end
    nil
  end
end

