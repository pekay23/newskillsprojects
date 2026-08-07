require 'sinatra/base'
require 'json'
require_relative 'database'
require_relative 'reports/workorder_summary'

class ReportEngineApp < Sinatra::Base
  configure do
    set :bind, '0.0.0.0'
    set :port, ENV['PORT'] || 8084
  end

  get '/health' do
    content_type :json
    { status: 'ok', service: 'report-engine' }.to_json
  end

  # The API Gateway mounts this service under /api/v1/reports
  # so this endpoint will be available at /api/v1/reports/workorders/summary
  get '/workorders/summary' do
    format = params['format'] || 'json'
    
    if format == 'pdf'
      content_type 'application/pdf'
      attachment 'workorder_summary.pdf'
      WorkorderSummaryReport.generate_pdf
    else
      content_type :json
      WorkorderSummaryReport.generate_json.to_json
    end
  end

  run! if app_file == $0
end
