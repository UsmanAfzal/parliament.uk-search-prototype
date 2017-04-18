require 'sinatra'
require 'sinatra/content_for'

require './multiview'


require 'pugin'

require 'parliament'
require 'parliament/open_search'
require './helpers/pagination'

require 'i18n'
require 'i18n/backend/fallbacks'

class Search < Sinatra::Application
	register Sinatra::MultiView

	#set :views, [Pugin.views_path, 'views']
	set :view_paths, [ './views/', Pugin.views_path ]
  set :view_options, { :layout => '/pugin/layouts/pugin-sinatra' }

  Parliament::Request::OpenSearchRequest.base_url = ENV['OPENSEARCH_DESCRIPTION_URL']

	helpers do
		# Construct a link to +url_fragment+, which should be given relative to
		# the base of this Sinatra app.  The mode should be either
		# <code>:path_only</code>, which will generate an absolute path within
		# the current domain (the default), or <code>:full_url</code>, which will
		# include the site name and port number.  The latter is typically necessary
		# for links in RSS feeds.  Example usage:
		#
		#   link_to "/foo" # Returns "http://example.com/myapp/foo"
		#
		#--
		# Thanks to cypher23 on #mephisto and the folks on #rack for pointing me
		# in the right direction.
		def link_to url_fragment, mode=:path_only
			case mode
			when :path_only
				base = request.script_name
			when :full_url
				if (request.scheme == 'http' && request.port == 80 ||
						request.scheme == 'https' && request.port == 443)
					port = ""
				else
					port = ":#{request.port}"
				end
				base = "#{request.scheme}://#{request.host}#{port}#{request.script_name}"
			else
				raise "Unknown script_url mode #{mode}"
			end
			"#{base}#{url_fragment}"
		end
	end

  get '/' do
    @query_parameter = nil

    show 'search/index'
  end

  get '/search' do
    @query_parameter = params[:q]
    @start_page = params[:start_page] || Parliament::Request::OpenSearchRequest.open_search_parameters[:start_page]
    @start_page = @start_page.to_i
    @count = Parliament::Request::OpenSearchRequest.open_search_parameters[:count]

    request = Parliament::Request::OpenSearchRequest.new(headers: { 'Accept' => 'application/atom+xml' },
                                                         builder: Parliament::Builder::OpenSearchResponseBuilder)

    begin
      logger.info "Making a query for '#{@query_parameter}' using the base_url: '#{request.base_url}'"
      @results = request.get({ query: @query_parameter, start_page: @start_page })
      @results_total = @results.totalResults

      show 'search/results'
    rescue Parliament::ServerError
      show 'search/no_results'
    end
  end

  run! if app_file == $PROGRAM_NAME
end
