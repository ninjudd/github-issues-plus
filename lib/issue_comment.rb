require 'helpers'

class IssueComment
  include Helpers

  attr_reader :repo, :id

  def initialize(repo, data)
    @repo = repo
    @id   = data.delete('id')
    @data = data unless data.empty?
  end

  def token
    repo.token
  end

  def hook
    repo.hook
  end

  def url
    "#{repo.url}/issues/comments/#{id}"
  end

  def body
    @body ||= hook.substitute(data['body'])
  end
end
