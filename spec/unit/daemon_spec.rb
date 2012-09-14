require 'spec_helper'

describe RCelery::Daemon do
  include RR::Adapters::RRMethods

  before(:each) do
    # @channel, @queue = stub_amqp
  end

  after :each do
    RCelery.stop if RCelery.running?
  end

  describe '.new' do
    it 'sets a config instance variable' do
      d = RCelery::Daemon.new([])
      d.instance_variable_get(:@config).should be_an_instance_of(RCelery::Configuration)
    end

    it 'sets the host using -n on the config object' do
      d = RCelery::Daemon.new(['-n','hostname'])
      d.instance_variable_get(:@config).host.should == "hostname"
    end

    it 'sets the host using --hostname on the config object' do
      d = RCelery::Daemon.new(['--hostname','another_hostname'])
      d.instance_variable_get(:@config).host.should == "another_hostname"
    end

    it 'sets the port using -p on the config object' do
      d = RCelery::Daemon.new(['-p','19567'])
      d.instance_variable_get(:@config).port.should == 19567
    end

    it 'sets the port using --port on the config object' do
      d = RCelery::Daemon.new(['--port','5677'])
      d.instance_variable_get(:@config).port.should == 5677
    end

    it 'sets the vhost using -v on the config object' do
      d = RCelery::Daemon.new(['-v','/qa'])
      d.instance_variable_get(:@config).vhost.should == "/qa"
    end

    it 'sets the vhost using --vhost on the config object' do
      d = RCelery::Daemon.new(['--vhost','/stage'])
      d.instance_variable_get(:@config).vhost.should == "/stage"
    end

    it 'sets the vhost using -v on the config object' do
      d = RCelery::Daemon.new(['-v','/qa'])
      d.instance_variable_get(:@config).vhost.should == "/qa"
    end

    it 'sets the vhost using --vhost on the config object' do
      d = RCelery::Daemon.new(['--vhost','/stage'])
      d.instance_variable_get(:@config).vhost.should == "/stage"
    end

    it 'sets the username using -u on the config object' do
      d = RCelery::Daemon.new(['-u','tester'])
      d.instance_variable_get(:@config).username.should == "tester"
    end

    it 'sets the username using --username on the config object' do
      d = RCelery::Daemon.new(['--username','testerson'])
      d.instance_variable_get(:@config).username.should == "testerson"
    end

    it 'sets the password using -w on the config object' do
      d = RCelery::Daemon.new(['-w','testpass'])
      d.instance_variable_get(:@config).password.should == "testpass"
    end

    it 'sets the password using --password on the config object' do
      d = RCelery::Daemon.new(['--password','another_pass'])
      d.instance_variable_get(:@config).password.should == "another_pass"
    end

    it 'sets the vhost using -a on the config object' do
      d = RCelery::Daemon.new(['-a','test'])
      d.instance_variable_get(:@config).application.should == "test"
    end

    it 'sets the vhost using --application on the config object' do
      d = RCelery::Daemon.new(['--application','another_test'])
      d.instance_variable_get(:@config).application.should == "another_test"
    end

    it 'sets the workers using -W on the config object' do
      d = RCelery::Daemon.new(['-W','3'])
      d.instance_variable_get(:@config).worker_count.should == 3
    end

    it 'sets the workers using --workers on the config object' do
      d = RCelery::Daemon.new(['--workers','5'])
      d.instance_variable_get(:@config).worker_count.should == 5
    end

    it 'sets the amqp_auto_recovery using -c on the config object' do
      d = RCelery::Daemon.new(['-c','true'])
      d.instance_variable_get(:@config).amqp_auto_recovery.should == true
    end

    it 'sets the amqp_auto_recovery using --connection_recovery on the config object' do
      d = RCelery::Daemon.new(['--connection_recovery','true'])
      d.instance_variable_get(:@config).amqp_auto_recovery.should == true
    end

    it 'sets the amqp_reconnect_wait_time using -C on the config object' do
      d = RCelery::Daemon.new(['-C','30'])
      d.instance_variable_get(:@config).amqp_reconnect_wait_time.should == 30
    end

    it 'sets the amqp_reconnect_wait_time using --connection_retry_wait on the config object' do
      d = RCelery::Daemon.new(['--connection_retry_wait','40'])
      d.instance_variable_get(:@config).amqp_reconnect_wait_time.should == 40
    end

    it 'requires files specified using -t' do
      d = RCelery::Daemon.new(['-t','config/libtasks'])
      Libtasks.should be
    end

    it 'requires files specified using --tasks' do
      d = RCelery::Daemon.new(['--tasks','config/libtasks'])
      Libtasks.should be
    end

    it 'requires multiple files specified using -t' do
      d = RCelery::Daemon.new(['-t','config/libtasks,config/moretasks'])
      Libtasks.should be
      Moretasks.should be
    end

    it 'requires multiple files specified using --tasks' do
      d = RCelery::Daemon.new(['--tasks','config/libtasks,config/moretasks'])
      Libtasks.should be
      Moretasks.should be
    end

    it 'requires config/environment when using -r' do
      require 'rcelery/rails'
      stub(RCelery::Rails).get_config_hash { {} }
      d = RCelery::Daemon.new(['-r'])
      Rails.should be
    end

    it 'updates the config object with the config hash when using -r' do
      require 'rcelery/rails'
      stub(RCelery::Rails).get_config_hash { {:application => "rails_app"} }
      d = RCelery::Daemon.new(['-r'])
      d.instance_variable_get(:@config).application.should == "rails_app"
    end

    it 'sets the Rails logger to auto flush when using -r' do
      require 'rcelery/rails'
      stub(RCelery::Rails).get_config_hash { {:application => "rails_app"} }
      d = RCelery::Daemon.new(['-r'])
      Rails.logger.auto_flushing.should be_true
    end

    it 'requires config/environment when using --rails' do
      require 'rcelery/rails'
      stub(RCelery::Rails).get_config_hash { {} }
      d = RCelery::Daemon.new(['--rails'])
      Rails.should be
    end

    it 'updates the config object with the config hash when using --rails' do
      require 'rcelery/rails'
      stub(RCelery::Rails).get_config_hash { {:application => "rails_app"} }
      d = RCelery::Daemon.new(['--rails'])
      d.instance_variable_get(:@config).application.should == "rails_app"
    end

    it 'sets the Rails logger to auto flush when using --rails' do
      require 'rcelery/rails'
      stub(RCelery::Rails).get_config_hash { {:application => "rails_app"} }
      d = RCelery::Daemon.new(['--rails'])
      Rails.logger.auto_flushing.should be_true
    end

    it 'overrides config set by the rails options with subsequent options' do
      require 'rcelery/rails'
      stub(RCelery::Rails).get_config_hash { {:application => "rails_app"} }
      d = RCelery::Daemon.new(['--rails','-a','another_app'])
      d.instance_variable_get(:@config).application.should == "another_app"
    end
  end
end
