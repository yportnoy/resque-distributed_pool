require 'resque/distributed_pool/member'

module Resque
  # Distributed Pool is a clustered resque-pool
  class DistributedPool
    class << self
      attr_reader :member
      attr_accessor :config
      def init(started_pool)
        @member = Member.new(started_pool)
      end
    end
  end
end
