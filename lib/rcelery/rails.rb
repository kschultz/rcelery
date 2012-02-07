require 'qusion'

module RCelery
  def self.thread
    @thread ||= Qusion.thread
  end

  module Rails
    def self.initialize
      environment_config = get_config_hash
      config = RCelery::Configuration.new(environment_config)
      if config.eager_mode
        RCelery.start(config)
      else
        Qusion.start(config.to_hash) do
          RCelery.start(config)
        end
      end
    rescue Errno::ENOENT
      #noop
    end

    def self.get_config_hash
      config_file = File.join(::Rails.root, 'config', 'rcelery.yml')
      YAML.load_file(config_file)[::Rails.env]
    end
  end
end
