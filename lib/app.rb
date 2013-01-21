require 'sinatra'
require 'json'
require 'faraday'
require 'faraday_middleware'
require 'repo'
require 'issue'
require 'issue_comment'

class App < Sinatra::Base
  enable :sessions

  def oauth
    @oauth ||= Faraday.new(:url => "https://github.com/", :headers => {:accept => 'application/json'}) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter Faraday.default_adapter
    end
  end

  get '/issues/:user/:repo' do
    if token = session[:token]
      @repo = Repo.new("#{params[:user]}/#{params[:repo]}")
      @repo.token = token
      @repo.opts  = params
      erb :index
    else
      url = oauth.build_url("/login/oauth/authorize", {
        :client_id => settings.client_id,
        :scope     => 'repo',
        :state     => request.url,
      })
      redirect url.to_s
    end
  end

  get '/issues/authorize' do
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
    @payload = params['payload']
    @repo    = Repo.new(payload['repository'])
    @issue   = Issue.new(payload['issue'])
    @comment = IssueComment.new(payload['comment']) if payload['comment']

    @repo.token = @repo.hook.access_token
  end

  post '/hooks/issues' do
    parse_payload
    action = @payload['action']

    labels = @repo.hook.action_labels(action)

    if action == 'opened'
      labels += @repo.hook.message_labels(@issue.body)

      @issue.update!(:milestone => @repo.hook.message_milestone(@issue.body))
      @issue.update!(:assignee  => @repo.hook.message_assignee(@issue.body))
    end

    issue.update_labels!(labels)
  end

  post '/hooks/issue_comment' do
    parse_payload

    if issue.data['closed_at'] == issue.data['updated_at']
      # Avoid race condition when "Close & comment" is clicked by waiting and
      # then reloading the issue labels.
      sleep 5
      issue.reload!
    end

    @issue.update!(:milestone => @repo.hook.message_milestone(@comment.body))
    @issue.update!(:assignee  => @repo.hook.message_assignee(@comment.body))

    labels = @repo.hook.action_labels(:commented) + @repo.hook.message_labels(@comment.body)
    @issue.update_labels!(labels)
  end
end
