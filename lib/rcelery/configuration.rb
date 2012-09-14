require 'configtoolkit'
require 'configtoolkit/hashreader'
require 'configtoolkit/hashwriter'
require 'configtoolkit/overridereader'

module RCelery
  class Configuration < ConfigToolkit::BaseConfig
    add_optional_param(:host, String, 'localhost')
    add_optional_param(:port, Integer, 5672)
    add_optional_param(:vhost, String, '/')
    add_optional_param(:username, String, 'guest')
    add_optional_param(:password, String, 'guest')
    add_optional_param(:application, String, 'application')
    add_optional_param(:worker_count, Integer, 1)
    add_optional_param(:eager_mode, ConfigToolkit::Boolean, false)
    add_optional_param(:amqp_auto_recovery, ConfigToolkit::Boolean, false)

    def initialize(options = {})
      load(ConfigToolkit::HashReader.new(options))
    end

    def to_hash
      dump(ConfigToolkit::HashWriter.new)
    end

    def update_with_hash(options = {})
      options = symbolize_options(options)
      load(ConfigToolkit::OverrideReader.new(ConfigToolkit::HashReader.new(to_hash), ConfigToolkit::HashReader.new(options)))
    end

    private

    def symbolize_options(options = {})
      options.inject({}) do |new_options, (key, value)|
        new_options[(key.to_sym rescue key) || key] = value
        new_options
      end
    end
  end
end

