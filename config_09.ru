#run lambda { |env| [200, {'Content-Type'=>'text/plain'}, StringIO.new("Hello 3 lambda!\n")] }

require './src/muffinland_09_cumulative_db'
run Muffinland.new("./src/views/")

