require 'prawn'
require 'prawn/table'

class WorkorderSummaryReport
  def self.generate_json
    # Cross-schema query using Sequel
    # Reads from workorders schema
    query = <<-SQL
      SELECT 
        status, 
        COUNT(id) as count
      FROM workorders.work_orders
      GROUP BY status
    SQL
    
    begin
      results = DB[query].all
      { status: "success", data: results }
    rescue => e
      { status: "error", message: e.message }
    end
  end

  def self.generate_pdf
    data = generate_json
    
    pdf = Prawn::Document.new
    pdf.text "Raymond Gray IFM - Work Order Summary", size: 24, style: :bold
    pdf.move_down 20
    
    if data[:status] == "success"
      table_data = [["Status", "Count"]]
      data[:data].each do |row|
        table_data << [row[:status].to_s.capitalize, row[:count].to_s]
      end
      
      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'DDDDDD'
      end
    else
      pdf.text "Error generating report data: #{data[:message]}"
    end
    
    pdf.render
  end
end
