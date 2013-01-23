require 'helpers'

class Repo
  include Helpers

  attr_reader :name, :opts
  attr_accessor :token

  def initialize(data = {}, opts = {})
    data  = {'full_name' => data} if data.kind_of?(String)
    @name = data.delete('full_name')
    @data = data unless data.empty?
    @opts = opts
  end

  def admin?
    if permissions = http_get('')['permissions']
      pp permissions
      permissions['admin']
    end
  end

  def filter_params
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
    http_get('issues', filter_params.merge(:per_page  => 100))
  end

  def group_by
    @group_by ||= (opts[:group_by] || 'milestone').to_sym
  end

  def hook
    @hook ||= Hook.get(name)
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
    "#{issues} (by #{group_by})"
  end

  def issues_by
    issues.group_by do |issue|
      issue[group_by.to_s]
    end.sort_by do |group, issues|
      -(group ? issues.count : 0)
    end
  end

  def url
    "https://api.github.com/repos/#{name}"
  end

  def html_url
    "https://github.com/#{name}"
  end

  def group_url(group)
    case group_by
    when :assignee then
      http.build_url("#{html_url}/issues/assigned/#{group_id(group)}", filter_params)
    when :milestone then
      http.build_url("#{html_url}/issues", filter_params.merge(:milestone => group_id(group)))
    end
  end

  def pivot_url(group)
    pivot = case group_by
            when :milestone then :assignee
            when :assignee  then :milestone
            end

    params = filter_params.dup
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
