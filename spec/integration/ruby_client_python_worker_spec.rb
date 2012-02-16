require 'integration/spec_helper'
require 'system_timer'

describe 'Ruby Client' do
  include Tasks

  it 'is able to talk to a python worker' do
    result = add.delay(5,10)
    result.wait.should == 15
  end

  it 'can send tasks scheduled in the future to python workers' do
    result = add.apply_async(:args => [5,3], :eta => Time.now + 5)

    result.wait.should == 8
  end

  it 'is able to call tasks not in its library' do
    result = RCelery::Task.send_task('r_celery.integration.not_in_ruby', :args => [4,8], :routing_key => 'rcelery.python.integration')
    result.wait.should == 16
  end
end
