require 'resque/distributed_pool'

module Resque
  class Pool

    # add the running pool to distributed pool in order to manipulate it
    def self.run
      if GC.respond_to?(:copy_on_write_friendly=)
        GC.copy_on_write_friendly = true
      end
      started_pool = Resque::Pool.new(choose_config_file).start
      Resque::DistributedPool.member.pool = started_pool
      started_pool.join
      Resque::DistributedPool.member.unregister
    end

    # performed inside the run loop, must check for any distributed pool updates
    original_maintain_worker_count = instance_method(:maintain_worker_count)
    define_method(:maintain_worker_count) do
      distributed_pool_update
      original_maintain_worker_count.bind(self).()
    end


    def distributed_pool_update
      Resque::DistributedPool.member.check_for_worker_count_adjustment
      Resque::DistributedPool.member.ping
    end

    def adjust_worker_counts(worker, number)
      puts "Old config #{@config}"
      if @config[worker].to_i + number < 0
        over_adjustment = "#{worker}:#{@config[worker].to_i + number}"
        @config[worker] = 0
        puts "New config #{@config}"
        over_adjustment
      else
        @config[worker] = @config[worker].to_i + number
        puts "New config #{@config}"
        ""
      end
    end
  end
end