require 'sysrandom/securerandom'

desc 'Start application'
task :rackup do
  system({ 'SESSION_SECRET' => SecureRandom.hex(64) }, 'rackup')
end