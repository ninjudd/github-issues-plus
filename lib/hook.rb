class Hook
  include DataMapper::Resource

  property :repo,                         String, :key => true
  property :label_prefix,                 String
  property :removal_prefix,               String
  property :milestone_prefix,             String
  property :assignee_prefix,              String
  property :update_labels_when_opened,    String
  property :update_labels_when_closed,    String
  property :update_labels_when_reopened,  String
  property :update_labels_when_commented, String
  property :substitutions,                Json

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

  def strip_prefix(label, prefix)
    label[prefix.count..-1] if label.start_with?(prefix)
  end

  def removal(label)
    strip_prefix(label, removal_prefix)
  end

  def addition(label)
    strip_prefix(label, label_prefix)
  end

  def words(body)
    body.scan(/\s/)
  end

  def message_labels(body)
    labels = []
    if label_prefix or removal_prefix
      words(body).select do |word|
        next if word.start_with?(assignee_prefix) or word.start_with?(milestone_prefix)
        labels << word if word.start_with?(label_prefix) or word.start_with?(removal_prefix)
      end
    end
    labels
  end

  def message_milestone(repo, body)
    words(body).each do |word|
      if milestone = strip_prefix(word, milestone_prefix)
        return repo.milestone_number(milestone)
      end
    end if milestone_prefix
    nil
  end

  def message_assignee(body)
    words(body).each do |word|
      if user = strip_prefix(word, assignee_prefix)
        return user
      end
    end if assignee_prefix
    nil
  end
end
