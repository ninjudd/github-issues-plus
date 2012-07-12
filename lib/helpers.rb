require 'faraday'
require 'faraday_middleware'

module Helpers
  def make_url(host, query_params)
    params = Faraday::Utils::ParamsHash.new
    params.update(query_params)
    "#{host}?#{params.to_query}"
  end

  def http
    @http ||= Faraday.new(:url => url) do |conn|
      conn.request :oauth2, token
      conn.response :json
      conn.response :raise_error
      conn.adapter Faraday.default_adapter
    end
  end

  def http_get(path, params = {})
    response = http.get(path, params.merge(:per_page => 100))

    if next_link = link_header(:next, response.headers)
      rest = http_get(next_link)
      response.body + rest
    else
      response.body
    end
  end

  def data
    @data ||= http_get('')
  end

  def reload!
    @data = nil
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
