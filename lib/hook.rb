class Hook
  include DataMapper::Resource

  property :repo,                         String, :key => true
  property :access_token,                 String
  property :label_prefix,                 String
  property :milestone_prefix,             String
  property :assignee_prefix,              String
  property :update_labels_when_opened,    String
  property :update_labels_when_closed,    String
  property :update_labels_when_reopened,  String
  property :update_labels_when_commented, String
  property :removal_prefix,               String
  property :substitutions,                Json

  TOKEN_REGEX = /\"[^\"]+\"|[-\d\w]+/
  USER_REGEX  = /[-\d\w]+/

  def action_labels(action)
    if update_labels = send("update_labels_when_#{action}")
      update_labels.split(/,\s*/)
    else
      []
    end
  end

  def substitute(body)
    substitutions.each do |string, replacement|
      body = body.gsub(string, replacement)
    end if substitutions
    body
  end

  def message_labels(body)
    if prefix = label_prefix
      body = scrub_prefixes(body, ['milestone_prefix', 'assignee_prefix'])
      body.scan(/#{prefix}(#{TOKEN_REGEX})/).map(&:first)
    else
      []
    end
  end

  def scrub_prefixes(body, prefixes)
    prefixes.each do |prefix|
      body = body.gsub(send(prefix), '') if data[prefix]
    end
    body
  end

  def message_milestone(body)
    if prefix = milestone_prefix
      title = body.scan(/#{prefix}(#{TOKEN_REGEX})/).map(&:first).last
      milestone_number(title)
    end
  end

  def message_assignee(body)
    if prefix = assignee_prefix
      body.scan(/#{prefix}@(#{USER_REGEX})/).map(&:first).last
    end
  end

  def removal(label)
    if removal_prefix and label =~ /#{removal_prefix}(#{TOKEN_REGEX})/
      $1
    end
  end
end
