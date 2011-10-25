Gem::Specification.new do |s|
  s.name = 'rcelery'
  s.summary = 'Ruby implementation of the Python Celery library.'
  s.version = '1.0.0'

  ignore = ['.gitignore']
  s.files = Dir['spec/**/*', 'lib/**/*', 'bin/**/*', 'rails/**/*',
                'rcelery.gemspec', 'Gemfile', 'LICENSE', 'Rakefile']
  s.test_files = Dir['spec/**/*']
  s.executables << 'rceleryd'
  s.require_paths = ['lib']

  s.authors = ['John MacKenzie', 'Kris Schultz', 'Nat Williams']
  s.homepage = 'https://github.com/leapfrogdevelopment/rcelery'
  s.email = 'oss@leapfrogdevelopment.com'

  s.add_dependency('amqp', '~> 0.7.3')
  s.add_dependency('uuid', '~> 2.0')
  s.add_dependency('json', '~> 1.0')
  s.add_dependency('configtoolkit', '~> 2.3')
  s.add_dependency('qusion', '~> 0.1.9')

  s.add_development_dependency('rspec', '~> 2.6')
  s.add_development_dependency('rake', '~> 0.9.2')
  s.add_development_dependency('rr', '~> 1.0')
  s.add_development_dependency('SystemTimer', '~> 1.1')
  s.add_development_dependency('foreman', '~> 0.20')
end

