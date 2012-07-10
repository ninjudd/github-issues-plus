require 'rubygems'
require 'sinatra'
require 'faraday'
require 'faraday_middleware'
require 'json'
require 'pp'

set :port, ARGV[0] || 8080
enable :sessions

get '/issues/:user/:repo' do
  begin
    token = session[:token]
    @repo = Repo.new(token, params)
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
    :state         => params[:state],
  )
  session[:token] = response.body['access_token']

  redirect params[:state]
end

def github
  @github ||= Faraday.new(:url => "https://github.com/", :headers => { :accept =>  'application/json'}) do |conn|
    conn.request :json
    conn.response :json
    conn.adapter Faraday.default_adapter
  end
end

def make_url(host, query_params)
  params = Faraday::Utils::ParamsHash.new
  params.update(query_params)
  "#{host}?#{params.to_query}"
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
      :milestone => opts[:milestone],
      :assignee  => opts[:assignee],
    }
    params.delete_if {|k,v| v.nil?}
    params
  end

  def issues
    http_get('issues', http_params.merge(:per_page  => 100))
  end

  def group_by
    @group_by ||= (opts[:group_by] || 'assignee').to_sym
  end

  def group_description
    issues = "issues"

    if number = opts[:milestone]
      if number == 'none'
        issues = "#{issues} with no milestone"
      else
        milestone   = http_get("milestones/#{number}")['title']
        issues = "#{milestone} #{issues}"
      end
    end
    issues = "#{opts[:state]} #{issues}"           if opts[:state]
    issues = "#{opts[:assignee]}'s #{issues}"      if opts[:assignee]
    issues = "#{issues} labelled #{opts[:labels]}" if opts[:labels]
    "#{opts[:user]}/#{opts[:repo]} - #{issues} (by #{group_by})"
  end

  def issues_by
    issues.group_by do |issue|
      issue[group_by.to_s]
    end.sort_by do |group, issues|
      -(group ? issues.count : 0)
    end
  end

  def url
    "https://api.github.com/repos/#{opts[:user]}/#{opts[:repo]}"
  end

  def html_url
    "https://github.com/#{opts[:user]}/#{opts[:repo]}"
  end

  def group_url(group)
    case group_by
    when :assignee then
      http.build_url("#{html_url}/issues/assigned/#{group_id(group)}", http_params)
    when :milestone then
      http.build_url("#{html_url}/issues", http_params.merge(:milestone => group_id(group)))
    end
  end

  def pivot_url(group)
    pivot = case group_by
    when :milestone then :assignee
    when :assignee  then :milestone
    end

    params = http_params.dup
    params.delete(pivot)
    make_url('', params.merge(group_by => group_id(group), :group_by => pivot))
  end

  def group_name(group)
    case group_by
    when :assignee then
      group ? group['login'] : 'unassigned'
    when :milestone then
      group ? group['title'] : 'no milestone'
    end
  end

  def group_id(group)
    return 'none' unless group
    return group['login'] if group_by == :assignee
    group['number']
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
    if response.status != 200
      raise Repo::HttpError, "HTTP #{response.status}: #{response.body['message']}"
    end

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
end

