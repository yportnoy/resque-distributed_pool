require 'resque/distributed_pool/member'

module Resque
  class DistributedPool
    class << self
      def init(cluster_name, environment_name, rebalance_on_termination)
        @member = Member.new(cluster_name, environment_name, rebalance_on_termination)
      end

      def member
        @member
      end
    end
  end
end