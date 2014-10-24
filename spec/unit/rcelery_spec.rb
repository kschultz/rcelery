require 'spec_helper'

describe RCelery do
  before :each do
    stub(AMQP).start
    stub(AMQP).stop

    @options = { :host => 'host', :port => 1234, :application => 'some_app' }
    @channel, @queue = stub_amqp
  end

  after :each do
    RCelery.stop if RCelery.running?
  end

  describe '.start' do
    # it 'starts amqp with the connection string based on the options passed less the application option' do
      # stub(RCelery).channel { @channel }

      # mock(AMQP).start(hash_including({
        # :host => 'host',
        # :port => 1234,
        # :username => 'guest',
        # :password => 'guest',
        # :vhost => '/'
      # }))

      # RCelery.start(@options)
    # end

    it "doesn't start AMQP if the connection is connected" do
      stub(RCelery).channel { @channel }
      connection = stub!.connected? { true }.subject
      stub(AMQP).connection { connection }

      RCelery.thread.should be_nil
    end

    it 'sets up the request, results and event exchanges' do
      channel = mock!.direct('celery', :durable => true) { 'request exchange' }.subject
      mock(channel).direct('celeryresults', :durable => true, :auto_delete => true) { 'results exchange' }
      mock(channel).topic('celeryev', :durable => true) { 'events exchange' }
      stub(channel).queue { @queue }

      stub(RCelery).channel { channel }

      RCelery.start(@options)

      RCelery.exchanges[:request].should == 'request exchange'
      RCelery.exchanges[:result].should == 'results exchange'
      RCelery.exchanges[:event].should == 'events exchange'
    end

    it 'does not setup auto recovery unless asked for by config' do
      channel = mock
      dont_allow(channel).auto_recovery=(true)
      stub(channel).direct
      stub(channel).topic
      stub(channel).queue { @queue }

      stub(RCelery).channel { channel }

      amqp_connection = mock
      dont_allow(amqp_connection).on_error
      stub(amqp_connection).connected? { false }
      stub(AMQP).connection { amqp_connection }
      RCelery.start(@options)
    end

    it 'sets up the channel to auto recover' do
      @options[:amqp_auto_recovery] = true

      channel = mock
      mock(channel).auto_recovery=(true)
      stub(channel).direct
      stub(channel).topic
      stub(channel).queue { @queue }

      amqp_connection = stub!.on_error.subject
      stub(amqp_connection).on_tcp_connection_loss
      stub(amqp_connection).on_tcp_connection_failure
      stub(amqp_connection).on_connection_interruption
      stub(amqp_connection).connected? { false }
      stub(AMQP).connection { amqp_connection }

      stub(RCelery).channel { channel }
      RCelery.start(@options)
    end

    it 'sets up the AMQP connection to attempt to reconnect on error' do
      @options[:amqp_auto_recovery] = true
      @options[:amqp_reconnect_wait_time] = 40

      channel = mock
      stub(channel).auto_recovery=(true)
      stub(channel).direct
      stub(channel).topic
      stub(channel).queue { @queue }
      stub(RCelery).channel { channel }

      amqp_connection = mock
      stub(amqp_connection).on_tcp_connection_loss
      stub(amqp_connection).on_tcp_connection_failure
      stub(amqp_connection).on_connection_interruption
      mock(amqp_connection).periodically_reconnect(40)
      mock(amqp_connection).on_error.returns do |block|
        block.call(amqp_connection, "blah")
      end
      stub(amqp_connection).connected? { false }
      stub(AMQP).connection { amqp_connection }

      RCelery.start(@options)
    end

    it 'sets up the AMQP connection to attempt to reconnect on tcp connection loss' do
      @options[:amqp_auto_recovery] = true
      @options[:amqp_reconnect_wait_time] = 40

      channel = mock
      stub(channel).auto_recovery=(true)
      stub(channel).direct
      stub(channel).topic
      stub(channel).queue { @queue }
      stub(RCelery).channel { channel }

      amqp_connection = mock
      stub(amqp_connection).on_error
      stub(amqp_connection).on_tcp_connection_failure
      stub(amqp_connection).on_connection_interruption
      mock(amqp_connection).periodically_reconnect(40)
      mock(amqp_connection).on_tcp_connection_loss.returns do |block|
        block.call(amqp_connection, "blah")
      end
      stub(amqp_connection).connected? { false }
      stub(AMQP).connection { amqp_connection }

      RCelery.start(@options)
    end

    it 'sets up the AMQP connection to attempt to reconnect on tcp connection failure' do
      @options[:amqp_auto_recovery] = true
      @options[:amqp_reconnect_wait_time] = 40

      channel = mock
      stub(channel).auto_recovery=(true)
      stub(channel).direct
      stub(channel).topic
      stub(channel).queue { @queue }
      stub(RCelery).channel { channel }

      amqp_connection = mock
      stub(amqp_connection).on_error
      stub(amqp_connection).on_tcp_connection_loss
      stub(amqp_connection).on_connection_interruption
      mock(amqp_connection).periodically_reconnect(40)
      mock(amqp_connection).on_tcp_connection_failure.returns do |block|
        block.call(amqp_connection, "blah")
      end
      stub(amqp_connection).connected? { false }
      stub(AMQP).connection { amqp_connection }

      RCelery.start(@options)
    end

    it 'sets up the AMQP connection to attempt to reconnect on connection interruption' do
      @options[:amqp_auto_recovery] = true
      @options[:amqp_reconnect_wait_time] = 40

      channel = mock
      stub(channel).auto_recovery=(true)
      stub(channel).direct
      stub(channel).topic
      stub(channel).queue { @queue }
      stub(RCelery).channel { channel }

      amqp_connection = mock
      stub(amqp_connection).on_error
      stub(amqp_connection).on_tcp_connection_loss
      stub(amqp_connection).on_tcp_connection_failure
      mock(amqp_connection).periodically_reconnect(40)
      mock(amqp_connection).on_connection_interruption.returns do |block|
        block.call(amqp_connection, "blah")
      end
      stub(amqp_connection).connected? { false }
      stub(AMQP).connection { amqp_connection }

      RCelery.start(@options)
    end

    it 'sets up the request queue and binds it to the request exchange correctly' do
      stub(@channel).direct('celery', anything) { 'request exchange' }
      mock(@channel).queue('rcelery.some_app', :durable => true) { @queue }
      mock(@queue).bind('request exchange', :routing_key => 'rcelery.some_app') { @queue }
      stub(RCelery).channel { @channel }
      RCelery.start(@options)

      RCelery.queue.should == @queue
    end

    it 'sets the running flag to true after completion' do
      stub(RCelery).channel { @channel }

      RCelery.running?.should be_false
      RCelery.start(@options)
      RCelery.running?.should be_true
    end

    it 'returns the self object (RCelery)' do
      stub(RCelery).channel { @channel }
      RCelery.start(@options).should == RCelery
    end

    it "doesn't start anything if eager_mode is set" do
      RCelery.start(@options.merge(:eager_mode => true))
      RCelery.running?.should be_true
    end

    it "returns a channel if AMQP has a connection and is connected" do
      RR::Space.reset_double(RCelery, :channel)
      stub_channel = Object.new
      connection = stub!.connected? { true }.subject
      stub(AMQP).connection { connection }
      stub(AMQP::Channel).new { stub_channel }
      RCelery.channel.should be(stub_channel)
    end
  end

  describe '.stop' do
    before :each do
      stub(RCelery).channel { @channel }
      RCelery.start(@options)
    end

    it 'stops AMQP' do
      mock(AMQP).stop

      RCelery.stop
    end

    describe 'updates various pieces of internal state:' do
      before :each do
        RCelery.stop
      end

      it 'sets the running state to false' do
        RCelery.running?.should be_false
      end

      it 'clears the exchanges' do
        RCelery.exchanges.should be_nil
      end

      it 'clears the thread' do
        RCelery.thread.should be_nil
      end

      it 'clears the request queue' do
        RCelery.queue.should be_nil
      end
    end
  end

  describe '.publish' do
    it 'publishes a message to the exchange specified, calling to_json first' do
      exchange = mock!.publish('some message'.to_json, anything).subject
      stub(exchange).auto_deleted? { false }
      stub(@channel).direct('celery', anything) { exchange }
      stub(RCelery).channel { @channel }
      RCelery.start(@options)

      stub(EM).next_tick.returns do |block|
        block.call
      end

      RCelery.publish(:request, 'some message', {:some => 'option'})
    end

    it 'uses the application name as the routing key if none is given' do
      exchange = mock!.publish(anything, hash_including({:routing_key => 'rcelery.some_app'})).subject
      stub(exchange).auto_deleted? { false }
      stub(@channel).direct('celery', anything) { exchange }
      stub(RCelery).channel { @channel }
      RCelery.start(@options)

      stub(EM).next_tick.returns do |block|
        block.call
      end

      RCelery.publish(:request, 'some message', {:some => 'option'})
    end

    it 'publishes the message with the application/json content_type' do
      exchange = mock!.publish(anything, hash_including({:content_type => 'application/json'})).subject
      stub(exchange).auto_deleted? { false }
      stub(@channel).direct('celery', anything) { exchange }
      stub(RCelery).channel { @channel }
      RCelery.start(@options)

      stub(EM).next_tick.returns do |block|
        block.call
      end

      RCelery.publish(:request, 'some message', {:some => 'option'})
    end

    it 'passes any options to the exchange' do
      exchange = mock!.publish(anything, hash_including({:some => 'option'})).subject
      stub(exchange).auto_deleted? { false }
      stub(@channel).direct('celery', anything) { exchange }
      stub(RCelery).channel { @channel }
      RCelery.start(@options)

      stub(EM).next_tick.returns do |block|
        block.call
      end

      RCelery.publish(:request, 'some message', {:some => 'option'})
    end

    it 'resets the exchange if it is set to auto_delete as it may not exist anymore' do
      exchange = mock!.publish(anything, hash_including({:some => 'option'})).subject
      stub(exchange).auto_deleted? { true }
      mock(exchange).reset
      stub(@channel).direct('celery', anything) { exchange }
      stub(RCelery).channel { @channel }
      RCelery.start(@options)

      stub(EM).next_tick.returns do |block|
        block.call
      end

      RCelery.publish(:request, 'some message', {:some => 'option'})
    end

    it 'schedules the message publish to occur at the next event machine tick' do
      exchange = stub
      stub(exchange).auto_deleted? { false }
      stub(@channel).direct('celery', anything) { exchange }
      stub(RCelery).channel { @channel }
      RCelery.start(@options)

      mock(EM).next_tick

      RCelery.publish(:request, 'some message', {:some => 'option'})
    end
  end
end
