require 'pp'
require 'sinatra'
require 'json'
require 'faraday'
require 'faraday_middleware'
require 'repo'
require 'issue'
require 'issue_comment'

class App < Sinatra::Base
  enable :sessions

  attr_reader :payload, :repo, :issue, :comment

  def oauth
    @oauth ||= Faraday.new(:url => "https://github.com/", :headers => {:accept => 'application/json'}) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  def repo_name
    "#{params[:user]}/#{params[:repo]}"
  end

  def init_repo
    if token = session[:token]
      @repo = Repo.new(repo_name, params)
      @repo.token = token
    else
      url = oauth.build_url("/login/oauth/authorize", {
        :client_id => settings.client_id,
        :scope     => 'repo',
        :state     => request.url,
      })
      redirect url.to_s
    end
  end

  def repo_admin?
    init_repo
    repo.admin?
  end

  get '/issues/:user/:repo' do
    init_repo
    erb :index
  end

  get '/hooks/:user/:repo' do
    return "Access Denied" unless repo_admin?

    @hook = Hook.first_or_create(repo_name)
    erb :hook
  end

  post '/hooks/:user/:repo' do
    return "Access Denied" unless repo_admin?

    hook = Hook.get(repo_name)
    params[:hook].delete_if {|k,v| v.empty?}
    hook.update(params[:hook])
    redirect "/hooks/#{repo_name}"
  end

  get '/authorize' do
    response = oauth.post("/login/oauth/access_token",
      :client_id     => settings.client_id,
      :client_secret => settings.client_secret,
      :code          => params[:code],
      :state         => params[:state],
    )
    session[:token] = response.body['access_token']

    redirect params[:state]
  end

  def parse_payload
    @payload = JSON.parse(params[:payload])
    @repo    = Repo.new(@payload['repository'])
    @issue   = Issue.new(@repo, @payload['issue'])
    @comment = IssueComment.new(@repo, @payload['comment']) if @payload['comment']
  end

  post '/hook' do
    parse_payload
    repo.token = params[:access_token]

    if comment
      if issue.data['closed_at'] == issue.data['updated_at']
        # Avoid race condition when "Close & comment" is clicked by waiting and
        # then reloading the issue labels.
        sleep 5
        issue.reload!
      end

      issue.update!(:milestone => repo.hook.message_milestone(repo, comment.body))
      issue.update!(:assignee  => repo.hook.message_assignee(comment.body))

      labels = repo.hook.action_labels(:commented) + repo.hook.message_labels(comment.body)
      issue.update_labels!(labels)
    else
      labels = repo.hook.action_labels(payload['action'])

      if action == 'opened'
        labels += repo.hook.message_labels(issue.body)

        issue.update!(:milestone => repo.hook.message_milestone(issue.body))
        issue.update!(:assignee  => repo.hook.message_assignee(issue.body))
      end

      issue.update_labels!(labels)
    end
  end
end
