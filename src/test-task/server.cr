require "http/server"
require "http/client"
require "json"

module Test::Task
  class Server

    @address : Socket::IPAddress

    class InputData
      include JSON::Serializable

      property endpoints : Array(Endpoint)
      property num_requests : Int8 = 10
      property retry_failed : Bool = false
    end

    class Endpoint
      include JSON::Serializable

      property method : String?
      property url : String
      property headers : Array(Header)?
      property body : String?
      property index : Int32?
    end

    class Header
      include JSON::Serializable

      property name : String
      property value : String
    end

    class RequestStats
      property latencies : Array(Int32)
      property fail_count : Int32
      property index : Int32

      def initialize
        @latencies = Array(Int32).new
        @fail_count = 0
        @index = 0
      end
    end

    class OutputData
      property endpoints : Array(EndpointStats) = Array(EndpointStats).new

      def to_json
        result = Hash(String, Array(Hash(String, Int32)) | Hash(String, Int32)).new
        result["endpoints"] = @endpoints.map { |e| e.to_hash }
        result["summary"] = Hash(String, Int32).new
        if are_all_endpoints_negative?
          result["summary"] = {
            "max"   => -1,
            "min"   => -1,
            "avg"   => -1,
            "fails" => @endpoints.map { |e| e.fails }.sum,
          }
        else
          average_sum = @endpoints.select { |e| e.avg.positive? }.map { |e| e.avg }.sum
          average = (average_sum / @endpoints.select { |e| e.avg.positive? }.size).to_i32
          result["summary"] = {
            "max"   => @endpoints.select { |e| e.max.positive? }.map { |e| e.max }.max,
            "min"   => @endpoints.select { |e| e.min.positive? }.map { |e| e.min }.min,
            "avg"   => average,
            "fails" => @endpoints.map { |e| e.fails }.sum,
          }
        end
        return result.to_pretty_json
      end

      private def are_all_endpoints_negative?
        negative_count = @endpoints.each.select { |e| e.min.negative? }.size
        return @endpoints.size == negative_count
      end
    end

    class EndpointStats
      property min : Int32
      property max : Int32
      property avg : Int32
      property fails : Int32

      def initialize(max : Int32 = -1, min : Int32 = -1, avg : Int32 = -1, fails : Int32 = 0)
        @max = max
        @min = min
        @avg = avg
        @fails = fails
      end

      def to_hash
        return {"max" => @max, "min" => @min, "avg" => @avg, "fails" => @fails}
      end
    end

    def initialize(port : Int16 = 8080)
      @server = HTTP::Server.new do |context|
        context.response.content_type = "application/json"
        body = context.request.body.not_nil!.gets_to_end
        input_data = InputData.from_json(body)
        context.response.print perform_requests(input_data)
      end
      @address = @server.bind_tcp "0.0.0.0", port
    end

    private def perform_requests(data : InputData)
      output_data = OutputData.new
      _endpoints = Array(Endpoint).new
      data.endpoints.each_with_index do |e, i|
        e.index = i
        _endpoints.push(e)
      end
      data.endpoints = _endpoints
      ch = Channel(RequestStats).new
      request_stats_unsorted = Array(RequestStats).new
      data.endpoints.each do |endpoint|
        spawn do
          puts "DEBUG: The #{endpoint.url} is being tested"
          ch.send(perform_request(endpoint, data.retry_failed, data.num_requests))
          puts "DEBUG: test for #{endpoint.url} is completed"
        end
      end
      data.endpoints.size.times do
        request_stats_unsorted.push(ch.receive)
      end
      request_stats_sorted = request_stats_unsorted.sort_by { |e| e.index }
      request_stats_sorted.each do |endpoint_initial_stats|
        if endpoint_initial_stats.latencies.empty?
          output_data.endpoints.push(EndpointStats.new(
            fails: endpoint_initial_stats.fail_count)
          )
        else
          output_data.endpoints.push(EndpointStats.new(
            max: endpoint_initial_stats.latencies.max,
            min: endpoint_initial_stats.latencies.min,
            avg: (endpoint_initial_stats.latencies.sum / endpoint_initial_stats.latencies.size).round.to_i32,
            fails: endpoint_initial_stats.fail_count)
          )
        end
      end
      puts "DEBUG: #{output_data.inspect}"
      return output_data.to_json
    end

    private def perform_request(endpoint : Endpoint, retry_failed : Bool = false, num_requests : Int8 = 10)
      rs = RequestStats.new
      rs.index = endpoint.index.not_nil!
      num_requests.times do |num|
        request_start_time = Time.local
        begin
          headers = HTTP::Headers.new
          unless endpoint.headers.nil?
            endpoint.headers.not_nil!.each do |h|
              headers[h.name] = h.value
            end
          end
          response = HTTP::Client.exec endpoint.method.nil? ? "GET" : endpoint.method.not_nil!.upcase, url: endpoint.url, headers: headers, body: endpoint.body
          if response.status_code < 300
            rs.latencies.push((Time.local - request_start_time).milliseconds)
          else
            rs.fail_count = rs.fail_count + 1
          end
        rescue e
          if retry_failed
            rs.fail_count = rs.fail_count + 1
          else
            rs.fail_count = 1
            break
          end
        end
      end
      puts "DEBUG: request stats for #{endpoint.url}: #{rs.inspect}"
      return rs
    end

    def listen
      puts "The test-task server listens on #{@address}"
      @server.listen
    end
  end
end
