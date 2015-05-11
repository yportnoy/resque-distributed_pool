module Resque
  class DistributedPool
    # Member is a single member of a resque pool cluster
    class Member
      attr_reader :cluster, :environment, :hostname, :rebalance_on_termination

      def initialize(cluster, environment, rebalance_on_termination = false)
        @cluster = cluster
        @environment = environment
        @hostname = `hostname`.strip
        @rebalance_on_termination = rebalance_on_termination
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
        rebalance_cluster if @rebalance_on_termination
        remove_member_command_queue
        remove_counts
      end

      def pool=(started_pool)
        @pool = started_pool
        update_counts
      end

      def check_for_worker_count_adjustment
        host_count_adjustment = Resque.redis.lpop(member_command_queue_key_name)
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

      def adjust_worker_counts(count_adjustment)
        worker_name, adjustment = count_adjustment.split(':')
        if @pool.nil?
          queue_commands_into_global_queue(count_adjustment)
        else
          kickback = @pool.adjust_worker_counts(worker_name, adjustment.to_i)
          queue_commands_into_global_queue(kickback) unless kickback.empty?
          update_counts
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

      def rebalance_cluster
        return if @pool.nil?
        current_workers = @pool.config
        current_workers.each do |key, value|
          queue_commands_into_global_queue("#{key}:#{value}")
        end
      end

      def queue_commands_into_global_queue(commands)
        if commands.is_a? Array
          commands.each do |command|
            Resque.redis.lpush(global_command_queue_key_name, command)
          end
        else
          Resque.redis.lpush(global_command_queue_key_name, commands)
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
