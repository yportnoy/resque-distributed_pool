require 'resque/distributed_pool'

module Resque
  # Resque Pool monkey patched methods for resque-pool
  class Pool
    # add the running pool to distributed pool in order to manipulate it
    def self.run
      if GC.respond_to?(:copy_on_write_friendly=)
        GC.copy_on_write_friendly = true
      end
      started_pool = Resque::Pool.new(choose_config_file).start
      Resque::DistributedPool.member.pool = started_pool if Resque::DistributedPool.member
      started_pool.join
      Resque::DistributedPool.member.unregister if Resque::DistributedPool.member
    end

    # performed inside the run loop, must check for any distributed pool updates
    original_maintain_worker_count = instance_method(:maintain_worker_count)
    define_method(:maintain_worker_count) do
      distributed_pool_update if Resque::DistributedPool.member
      original_maintain_worker_count.bind(self).call
    end

    def distributed_pool_update
      Resque::DistributedPool.member.check_for_worker_count_adjustment
      Resque::DistributedPool.member.ping
    end

    def adjust_worker_counts(worker, number)
      puts "Old config #{@config}"
      over_adjustment = ''
      if @config[worker].to_i + number < 0
        over_adjustment = "#{worker}:#{@config[worker].to_i + number}"
        @config[worker] = 0
      else
        @config[worker] = @config[worker].to_i + number
      end
      puts "New config #{@config}"
      over_adjustment
    end
  end
end
