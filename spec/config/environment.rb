module Rails
  class Logger
    attr_accessor :auto_flushing

    def initialize
      auto_flushing = false
    end
  end

  def self.logger
    @logger ||= Logger.new
  end
end
