require 'logger'

module Hystrix
  module Logging
    class Pretty < Logger::Formatter
      # Provide a call() method that returns the formatted message.
      def call(severity, time, program_name, message)
        "[#{program_name}] #{severity}: #{message}\n"
      end
    end

    def self.initialize_logger(log_target = STDOUT, level = ::Logger::INFO)
      @logger = ::Logger.new(log_target)
      @logger.level = level
      @logger.formatter = Pretty.new

      @logger
    end

    def self.logger
      defined?(@logger) ? @logger : initialize_logger
    end

    def self.logger=(log)
      @logger = (log ? log : ::Logger.new('/dev/null'))
    end

    def logger
      Logging.logger
    end
  end
end
