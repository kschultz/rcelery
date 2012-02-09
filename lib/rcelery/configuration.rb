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

    def initialize(options = {})
      load(ConfigToolkit::HashReader.new(options))
    end

    def to_hash
      dump(ConfigToolkit::HashWriter.new)
    end

    def update_with_hash(options = {})
      load(ConfigToolkit::OverrideReader.new(ConfigToolkit::HashReader.new(to_hash), ConfigToolkit::HashReader.new(options)))
    end
  end
end

