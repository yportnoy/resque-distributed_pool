require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Resque::DistributedPool::Member do
  before :all do
    @redis = Resque.redis
    @member = Resque::DistributedPool.init('test-cluster', 'test', true)
    @member.pool = Resque::Pool.new('foo' => 1)
    @hostname = `hostname`.strip
  end

  context '#register' do
    before :all do
      @member.register
    end

    it 'pings into redis to let the rest of the cluster know of it' do
      expect(@redis.hget('cluster:test-cluster:test', @hostname)).to_not be_nil
    end
  end

  context '#check_for_worker_count_adjustment' do
    before :all do
      @redis.lpush("cluster:test-cluster:test:#{@hostname}:command_queue", 'baz:-2')
      @redis.lpush("cluster:test-cluster:test:#{@hostname}:command_queue", 'bar:2')
    end

    it 'adjust worker counts if an adjustment exists on the local command queue' do
      2.times do
        @member.check_for_worker_count_adjustment
        expect(@redis.hget("cluster:test-cluster:test:#{@hostname}:running_workers", 'foo')).to eq '1'
        expect(@redis.hget("cluster:test-cluster:test:#{@hostname}:running_workers", 'bar')).to eq '2'
      end
    end

    it 'puts the counts it cannot adjust into the global queue' do
      @member.check_for_worker_count_adjustment
      expect(@redis.hget("cluster:test-cluster:test:#{@hostname}:running_workers", 'baz')).to eq '0'
      expect(@redis.lpop('cluster:test-cluster:test:command_queue')).to eq 'baz:-2'
    end
  end

  context '#unregister' do
    before :all do
      @redis.lpush("cluster:test-cluster:test:#{@hostname}:command_queue", 'foobar:2')
      @member.unregister
    end

    it 'removes everything about itself from redis' do
      expect(@redis.hget('cluster:test-cluster:test', @hostname)).to be_nil
      expect(@redis.get("cluster:test-cluster:test:#{@hostname}:running_workers")).to be_nil
      expect(@redis.get("cluster:test-cluster:test:#{@hostname}:command_queue")).to be_nil
    end

    it 'moves currently pending changes to the global queue' do
      expect(@redis.lpop('cluster:test-cluster:test:command_queue')).to eq 'foobar:2'
    end

    it 'moves all the current running workers into the global queue if rebalance_on_termination is set to true' do
      expect(@redis.lpop('cluster:test-cluster:test:command_queue')).to eq 'baz:0'
      expect(@redis.lpop('cluster:test-cluster:test:command_queue')).to eq 'bar:2'
      expect(@redis.lpop('cluster:test-cluster:test:command_queue')).to eq 'foo:1'
    end
  end

  after :all do
    @redis.del('cluster:test-cluster:test:command_queue')
  end
end
