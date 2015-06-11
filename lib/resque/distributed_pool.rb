require 'resque/distributed_pool/member'

module Resque
  # Distributed Pool is a clustered resque-pool
  class DistributedPool
    class << self
      attr_reader :member
      def init(cluster_name, environment_name, rebalance_on_termination)
        @member = Member.new(cluster_name, environment_name, rebalance_on_termination)
      end
    end
  end
end
