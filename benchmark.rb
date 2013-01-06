$:.push(File.dirname(__FILE__) + '/lib')
require 'php_serialize'
require 'benchmark'

TIMES = 10000
value1 = {[1, 2, 5] * 10 => {'b' * 40 => [1, 2, 'Hello world' * 200, {'c' => 33}]}}
value2 = {'125' * 10 => {'b' * 40 => [1, 2, 'Hello world' * 200, {'c' => 33}]}}
php1 = PHP.serialize(value1)
php2 = PHP.serialize_session(value2)

if value1 != PHP.unserialize(php1) || value2 != PHP.unserialize(php2)
  raise "serializer broken"
end

Benchmark.bmbm do |x|
  x.report("regular") do
    TIMES.times do
      PHP.unserialize(php1)
    end
  end
  x.report("session") do
    TIMES.times do
      PHP.unserialize(php2)
    end
  end
end