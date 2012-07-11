require 'faraday'

module Helpers
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
end
