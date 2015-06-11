require 'socket'
require 'gru'

module Resque
  class DistributedPool
    # Member is a single member of a resque pool cluster
    class Member
      attr_reader :cluster, :environment, :hostname, :rebalance_on_termination, :pool, :global_config

      def initialize(cluster, environment, global_config, rebalance = false)
        @cluster = cluster
        @environment = environment
        @hostname = Socket.gethostname
        @global_config = global_config
        register
      end

      def ping
        Resque.redis.hset(global_prefix, hostname, Time.now.utc)
      end

      def unping
        Resque.redis.hdel(global_prefix, hostname)
      end

      def register
        ping
      end

      def unregister
        unping
        remove_member_command_queue
        remove_counts
        @worker_count_manager.release_workers
      end

      def pool=(started_pool)
        @pool = started_pool
        client = Redis.new(Resque.redis.client.options)
        @worker_count_manager = Gru.with_redis_connection(client,@pool.config, (@global_config.empty? ? @pool.config : @global_config))
        @pool.instance_variable_set(:@config, @worker_count_manager.adjust_workers)
        update_counts
      end

      def check_for_worker_count_adjustment
        return unless @worker_count_manager
        host_count_adjustment = @worker_count_manager.adjust_workers
        return if host_count_adjustment.nil?
        adjust_worker_counts(host_count_adjustment)
      end

      private

      def global_prefix
        "cluster:#{@cluster}:#{@environment}"
      end

      def member_prefix
        "#{global_prefix}:#{@hostname}"
      end

      def global_command_queue_key_name
        "#{global_prefix}:command_queue"
      end

      def member_command_queue_key_name
        "#{member_prefix}:command_queue"
      end

      def running_workers_key_name
        "#{member_prefix}:running_workers"
      end

      def adjust_worker_counts(count_adjustments)
        count_adjustments.each do |worker, count|
          if @pool.nil?
            queue_commands_into_global_queue(count_adjustment)
          else
            @pool.adjust_worker_counts(worker, count)
            update_counts
          end
        end
      end

      def drain_member_command_queue
        queued_up_commands = []
        while Resque.redis.llen(member_command_queue_key_name) > 0
          queued_up_commands << Resque.redis.lpop(member_command_queue_key_name)
        end
        queued_up_commands
      end

      def remove_counts
        Resque.redis.del(running_workers_key_name)
      end

      def remove_member_command_queue
        queued_up_commands = drain_member_command_queue
        Resque.redis.del(member_command_queue_key_name)
        queue_commands_into_global_queue(queued_up_commands)
      end

      def queue_commands_into_global_queue(commands)
        commands = Array(commands)
        commands.each do |command|
          @worker_count_manager.release_workers(command)
        end
      end

      def update_counts
        return if @pool.nil?
        current_workers = @pool.config
        current_workers.each do |key, value|
          Resque.redis.hset(running_workers_key_name, key, value)
        end
      end
    end
  end
end
