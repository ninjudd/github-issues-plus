require 'helpers'

class Issue
  include Helpers

  attr_reader :repo, :number

  def initialize(repo, data)
    @repo   = repo
    @number = data.delete('number')
    @data   = data unless data.empty?
  end

  def token
    repo.token
  end

  def hook
    repo.hook
  end

  def url
    "#{repo.url}/issues/#{number}?access_token=#{token}"
  end

  def labels
    @labels ||= data['labels'].map {|label| label['name']}.to_set
  end

  def body
    @body ||= hook.substitute(data['body'])
  end

  def update_labels!(labels)
    if labels.any?
      old_labels = self.labels
      new_labels = old_labels.dup

      labels.each do |label|
        if remove_label = hook.removal(label)
          new_labels.delete(remove_label)
        else
          new_labels << label
        end
      end

      if old_labels != new_labels
        set_labels!(new_labels)
      end
    end
  end

  def set_labels!(labels)
    body = update!(:labels => labels.to_a)

    if missing = (body['errors'] || []).detect {|e| e['code'] == 'missing'}
      set_labels!(labels - missing['value'])
    end
  end

  def update!(attrs)
    attrs.delete_if {|k,v| v.nil?}
    return if attrs.empty?

    http.patch(url, attrs.to_json)
  end
end
