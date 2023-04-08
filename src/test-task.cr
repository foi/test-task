require "./test-task/*"

module Test::Task
  VERSION = "0.1.0"

end

server = Test::Task::Server.new
server.listen