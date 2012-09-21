require 'spec_helper'

describe RCelery::Task do
  module Tasks
    include RCelery::TaskSupport

    task(:name => 'different_name', :ignore_result => false, :routing_key => 'different_route')
    def add(a,b, options = {})
      noop(a + b + (options['c'] || 0))
    end

    task()
    def ignore
      'ignore_me'
    end

    def noop(val)
      val
    end
  end

  before :each do
    @task = RCelery::Task.all_tasks['different_name']
  end

  describe '.all_tasks' do
    it 'returns a hash of all tasks by name' do
      RCelery::Task.all_tasks.each do |name, task|
        task.name.should == name
      end
    end
  end

  describe '.result_queue' do
    it 'resets the results exchange as it is auto_delete and could have been deleted' do
      result_exchange = Object.new
      mock(result_exchange).reset

      result_queue = Object.new
      mock(result_queue).bind(result_exchange, hash_including(:routing_key => 'someuuid')) { result_queue }

      channel = Object.new
      mock(channel).queue('someuuid', hash_including(:durable => true, :auto_delete => true,
        :arguments => { 'x-expires' => 3600000 })) { result_queue }

      stub(RCelery).channel { channel }
      stub(RCelery).exchanges { {:result => result_exchange} }

      RCelery::Task.result_queue('some-uuid').should == result_queue
    end

    it 'returns the result_queue for the task_id' do
      result_exchange = Object.new
      stub(result_exchange).reset

      result_queue = Object.new
      mock(result_queue).bind(result_exchange, hash_including(:routing_key => 'someuuid')) { result_queue }

      channel = Object.new
      mock(channel).queue('someuuid', hash_including(:durable => true, :auto_delete => true,
        :arguments => { 'x-expires' => 3600000 })) { result_queue }

      stub(RCelery).channel { channel }
      stub(RCelery).exchanges { {:result => result_exchange} }

      RCelery::Task.result_queue('some-uuid').should == result_queue
    end
  end

  describe '.execute' do
    it 'establishes the result queue' do
      any_instance_of(RCelery::Task::Runner) do |t|
        stub(t).publish_result
      end

      result_exchange = Object.new
      stub(result_exchange).reset

      result_queue = Object.new
      mock(result_queue).bind(result_exchange, hash_including(:routing_key => 'guid')) { result_queue }

      channel = Object.new
      mock(channel).queue('guid', hash_including(:durable => true, :auto_delete => true,
        :arguments => { 'x-expires' => 3600000 })) { result_queue }

      stub(RCelery).channel { channel }
      stub(RCelery).exchanges { {:result => result_exchange} }

      task = {'task' => 'different_name', 'args' => [1,2], 'kwargs' => {'c' => 3}, 'id' =>  'guid'}

      RCelery::Task.execute(task)
    end

    it 'takes a message, determines what task class generated it and passes the args/kwargs returning an instnace of a task runner' do
      stub(RCelery::Task).result_queue
      any_instance_of(RCelery::Task::Runner) do |t|
        stub(t).publish_result
      end

      task = {'task' => 'different_name', 'args' => [1,2], 'kwargs' => {'c' => 3}, 'id' =>  'guid'}

      runner = nil
      lambda {
        runner = RCelery::Task.execute(task)
      }.should_not raise_error

      runner.should be_a(RCelery::Task::Runner)
    end

    it 'publishes the successful result to the result queue when ignore_result is false' do
      stub(RCelery::Task).result_queue
      mock(RCelery).publish(:result, { :result => 6, :status => 'SUCCESS',
        :task_id => 'guid', :traceback => [] }, hash_including(:persistent => true))

      task = {'task' => 'different_name', 'args' => [1,2], 'kwargs' => {'c' => 3}, 'id' =>  'guid'}

      RCelery::Task.execute(task)
    end

    it 'publishes the failed result to the result queue when ignore_result is false' do
      stub(RCelery::Task).result_queue
      task = {'task' => 'tasks.error', 'id' =>  'guid'}

      raised = Exception.new
      begin
        raise raised
      rescue Exception
      end

      Tasks.task(:ignore_result => false)
      Tasks.send(:define_method, :error) do
        raise raised
      end

      mock(RCelery).publish(:result, { :result => raised, :status => 'FAILURE',
        :task_id => 'guid', :traceback => raised.backtrace }, hash_including(:persistent => true)).subject

      RCelery::Task.execute(task)
    end
  end

  describe '#initialize' do
    it 'sets the name' do
      task = RCelery::Task.new(:name => 'some_name')
      task.name.should == 'some_name'
    end

    it 'sets the method' do
      task = RCelery::Task.new(:method => 'some_method')
      task.method.should == 'some_method'
    end

    it 'sets the routing key' do
      task = RCelery::Task.new(:routing_key => 'something')
      task.instance_variable_get(:@routing_key).should == 'something'
    end

    it 'sets ignore_result and expects it to be a boolean' do
      task = RCelery::Task.new(:ignore_result => false)
      task.ignore_result?.should be_false
    end

    it 'defaults ignore_result to true' do
      task = RCelery::Task.new
      task.ignore_result?.should be_true
    end
  end

  describe '#delay' do
    it 'publishes a message to the request exchange with the correct arguments' do
      stub(UUID).generate { 'some_uuid' }
      mock(RCelery).publish(:request, {:id => 'some_uuid', :task => 'different_name',
        :args => [1,2], :kwargs => {:some => 'kwarg'}}, hash_including(:persistent => true, :routing_key => 'different_route'))

      stub(RCelery::AsyncResult).new

      @task.delay(1,2,{:some => 'kwarg'})
    end
  end

  describe '#apply_async' do
    it 'can override routing key' do
      stub(UUID).generate { 'some_uuid' }
      mock(RCelery).publish(:request, {:id => 'some_uuid', :task => 'different_name',
        :args => [1,2], :kwargs => {:some => 'kwarg'}}, hash_including(:persistent => true, :routing_key => 'the_route'))

      stub(RCelery::AsyncResult).new

      @task.apply_async(:args=>[1,2],:kwargs=>{:some => 'kwarg'},:routing_key=>'the_route')
    end
  end

  describe '#retry' do
    it 'republishes a task using the current task id' do
      task = RCelery::Task.new(:ignore_result => false)
      task.request.update(
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :retries => 0,
        :args => [],
        :kwargs => {'this' => 'that'}
      )

      eta = Time.at(Time.now + (60 * 3))

      expected_options = {
        :args => [],
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :kwargs => {'this' => 'that'},
        :retries => 1,
        :eta => eta
      }
      mock(task).apply_async(expected_options)
      begin
        task.retry(:eta => eta)
      rescue RCelery::Task::RetryError
      end
    end

    it 'uses options passed to it before the request values' do
      task = RCelery::Task.new(:ignore_result => false)
      task.request.update(
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :retries => 0,
        :args => [],
        :kwargs => {'this' => 'that'}
      )

      eta = Time.at(Time.now + (60 * 3))

      expected_options = {
        :args => [1,2],
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :kwargs => {'another' => 'that'},
        :retries => 1,
        :eta => eta
      }
      mock(task).apply_async(expected_options)
      begin
        task.retry(:eta => eta, :args => [1,2], :kwargs => {'another' => 'that'})
      rescue RCelery::Task::RetryError
      end
    end

    it 'raises RetryError when retrying' do
      task = RCelery::Task.new(:ignore_result => false)
      task.request.update(
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :retries => 0,
        :args => [],
        :kwargs => {'this' => 'that'}
      )

      stub(task).apply_async()
      lambda { task.retry(:args => [1,2], :kwargs => {'another' => 'that'}) }.should raise_error(RCelery::Task::RetryError)
    end

    it 'raises MaxRetriesExceededError when max retries have been exceeded' do
      task = RCelery::Task.new(:ignore_result => false)
      task.request.update(
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :retries => 3,
        :args => [],
        :kwargs => {'this' => 'that'}
      )

      lambda { task.retry(:args => [1,2], :kwargs => {'another' => 'that'}) }.should raise_error(RCelery::Task::MaxRetriesExceededError)
    end

    it 'raises MaxRetriesExceededError when max retries defined in the options have been exceeded' do
      task = RCelery::Task.new(:ignore_result => false)
      task.request.update(
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :retries => 1,
        :args => [],
        :kwargs => {'this' => 'that'}
      )

      lambda { task.retry(:max_retries => 1, :args => [1,2], :kwargs => {'another' => 'that'}) }.should raise_error(RCelery::Task::MaxRetriesExceededError)
    end

    it 'raises a supplied exception when max retries have been exceeded' do
      class CustomMaxRetriesExceededError < StandardError; end
      task = RCelery::Task.new(:ignore_result => false)
      task.request.update(
        :task_id => 'abcdefghijklmnopqrstuvwxyzasdfgh',
        :retries => 3,
        :args => [],
        :kwargs => {'this' => 'that'}
      )

      lambda { task.retry(:exc => CustomMaxRetriesExceededError, :args => [1,2], :kwargs => {'another' => 'that'}) }.should raise_error(CustomMaxRetriesExceededError)
    end
  end

  describe "#send_task" do
    it 'creates a new task with the correct options' do
      expected_options = {
        :name => "new_name",
        :ignore_result => false
      }

      mock(RCelery::Task).new(expected_options) { stub("task").apply_async }

      RCelery::Task.send_task("new_name")
    end

    it 'accepts symbols for task names' do
      expected_options = {
        :name => "new_name",
        :ignore_result => false
      }

      mock(RCelery::Task).new(expected_options) { stub("task").apply_async }

      RCelery::Task.send_task(:new_name)
    end

    it "calls apply_async with the correct options" do
      expected_options = {
        :args => [1,2],
        :kwargs=>{:some => 'kwarg'},
        :routing_key=>'the_route'
      }
      mock.instance_of(RCelery::Task).apply_async(expected_options)

      RCelery::Task.send_task("new_name", :args=>[1,2], :kwargs=>{:some => 'kwarg'}, :routing_key=>'the_route')
    end
  end
end
