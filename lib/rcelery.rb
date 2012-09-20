require 'amqp'
require 'rcelery/task'
require 'rcelery/events'
require 'rcelery/worker'
require 'rcelery/configuration'
require 'rcelery/daemon'
require 'rcelery/task_support'
require 'rcelery/async_result'
require 'rcelery/eager_result'
require 'rcelery/version'

require 'rcelery/railtie' if defined?(Rails::Railtie)

module RCelery
  @running = false

  def self.start(config = {})
    config = Configuration.new(config) if config.is_a?(Hash)
    @config = config

    @application = config.application

    unless eager_mode?
      if AMQP.connection.nil? || !AMQP.connection.connected?
        @thread = Thread.new { AMQP.start(config.to_hash) }
      end

      channel = RCelery.channel
      setup_amqp_recovery

      @exchanges = {
        :request => channel.direct('celery', :durable => true),
        :result => channel.direct('celeryresults', :durable => true, :auto_delete => true),
        :event => channel.topic('celeryev', :durable => true)
      }
      @queue  = channel.queue(RCelery.queue_name, :durable => true).bind(
        exchanges[:request], :routing_key => RCelery.queue_name)
    end

    @running = true

    self
  end

  def self.stop
    AMQP.stop { EM.stop } unless eager_mode?
    @channel = nil
    @running = false
    @queue = nil
    @exchanges = nil
    @thread.kill unless eager_mode?
    @thread = nil
  end

  def self.channel
    @channel ||= get_new_channel
  end

  def self.get_new_channel
    wait_for_connection
    AMQP::Channel.new
  end

  def self.wait_for_connection
    while AMQP.connection.nil?; end
    while !AMQP.connection.connected?; end
  end

  def self.setup_amqp_recovery
    return unless @config.amqp_auto_recovery
    RCelery.channel.auto_recovery = true

    AMQP.connection.on_error do |conn, connection_close|
      conn.periodically_reconnect(@config.amqp_reconnect_wait_time)
    end
  end

  def self.thread
    @thread
  end

  def self.queue_name
    "rcelery.#{@application}"
  end

  def self.running?
    @running
  end

  def self.queue
    @queue
  end

  def self.exchanges
    @exchanges
  end

  def self.eager_mode?
    @config.eager_mode if @config
  end

  def self.publish(exchange, message, options = {})
    exchanges[exchange].redeclare if exchanges[exchange].auto_deleted?
    options[:routing_key] ||= queue_name
    options[:content_type] = 'application/json'
    exchanges[exchange].publish(message.to_json, options)
  end
end
