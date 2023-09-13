Vagrant.configure("2") do |config|
	config.vm.box = "ubuntu/trusty64"
	config.vm.hostname = 'hystrix-ruby.local'

	config.vm.provision :shell, :path => "scripts/vagrant.sh"
end
