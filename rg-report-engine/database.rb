require 'sequel'

# Connect to the Neon database
db_url = ENV['NEON_URL'] || 'postgres://user:pass@localhost/db'
DB = Sequel.connect(db_url)

# Test connection on startup
begin
  DB.test_connection
  puts "Report Engine connected to database successfully"
rescue => e
  puts "Failed to connect to database: #{e.message}"
end
