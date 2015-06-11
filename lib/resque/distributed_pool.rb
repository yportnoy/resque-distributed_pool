require 'resque/distributed_pool/member'

module Resque
  # Distributed Pool is a clustered resque-pool
  class DistributedPool
    class << self
      attr_reader :member
      def init(cluster_name, environment_name, global_config, rebalance)
        @member = Member.new(cluster_name, environment_name, global_config, rebalance)
      end
    end
  end
end
