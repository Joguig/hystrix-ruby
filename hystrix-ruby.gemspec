Gem::Specification.new do |s|
	s.name = %q{hystrix-ruby}
	s.version = "0.1.0"
	s.authors = ["Keith Thornhill"]
	s.date = %q{2013-04-08}
	s.description = %q{Hystrix for Ruby}
	s.email = %q{keith.thornhill@gmail.com}
	s.files = Dir['lib/**/*.rb']
	s.require_paths = ["lib"]
	s.summary = %q{Hystrix for Ruby}

	s.add_dependency 'celluloid', '>= 0.16.0'
	s.add_dependency 'atomic', '~> 1.1.14'
	s.add_dependency 'sinatra', '~> 1.4.5'
	s.add_development_dependency 'rspec'
	s.add_development_dependency 'simplecov-rcov'
	s.add_development_dependency 'timecop'
	#s.add_development_dependency 'debugger'
end
