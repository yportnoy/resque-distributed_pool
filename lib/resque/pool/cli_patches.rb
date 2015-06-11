require 'resque/distributed_pool/member'
require 'yaml'

module Resque
  class Pool
    # Command Line Interface monkey patch for resque-pool
    module CLI
      module_function

      original_setup_environment = instance_method(:setup_environment)

      define_method(:setup_environment) do |opts|
        original_setup_environment.bind(self).call(opts)
        puts "Starting as a cluster: #{opts[:cluster]} in #{opts[:environment]} environment, rebalance?: #{opts[:rebalance]}"
        global_config = parse_global_config(opts[:global_config]) unless opts[:global_config].nil?
        Resque::DistributedPool.init(opts[:cluster], opts[:environment], global_config, opts[:rebalance]) if opts[:cluster]
      end

      # rubocop:disable all
      def parse_options
        opts = Trollop::options do
          version "resque-pool #{VERSION} (c) nicholas a. evans"
          banner <<-EOS
resque-pool is the best way to manage a group (pool) of resque workers

When daemonized, stdout and stderr default to resque-pool.stdxxx.log files in
the log directory and pidfile defaults to resque-pool.pid in the current dir.

Usage:
   resque-pool [options]
where [options] are:
          EOS
          opt :config, 'Alternate path to config file', type: String, short: '-c'
          opt :appname, 'Alternate appname',         type: String,    short: '-a'
          opt :daemon, 'Run as a background daemon', default: false,  short: '-d'
          opt :stdout, 'Redirect stdout to logfile', type: String,    short: '-o'
          opt :stderr, 'Redirect stderr to logfile', type: String,    short: '-e'
          opt :nosync, 'Don\'t sync logfiles on every write'
          opt :pidfile, 'PID file location', type: String,    short: '-p'
          opt :environment, 'Set RAILS_ENV/RACK_ENV/RESQUE_ENV', type: String, short: '-E'
          opt :spawn_delay, 'Delay in milliseconds between spawning missing workers', type: Integer, short: '-s'
          opt :term_graceful_wait, 'On TERM signal, wait for workers to shut down gracefully'
          opt :term_graceful,     'On TERM signal, shut down workers gracefully'
          opt :term_immediate,     'On TERM signal, shut down workers immediately (default)'
          opt :single_process_group, 'Workers remain in the same process group as the master', default: false
          opt :cluster, 'Name of the cluster this resque-pool belongs to', type: String, short: '-C'
          opt :rebalance, 'In a cluster mode, On TERM signal rebalance', default: false, short: '-R'
          opt :global_config, 'Alternate path to the global config file', type: String, short: '-G'
        end
        if opts[:daemon]
          opts[:stdout] ||= 'log/resque-pool.stdout.log'
          opts[:stderr] ||= 'log/resque-pool.stderr.log'
          opts[:pidfile] ||= 'tmp/pids/resque-pool.pid'
        end
        opts
      end
      # rubocop:enable all

      def parse_global_config(global_config_path)
        return {} unless File.exists?(global_config_path)
        YAML.load(ERB.new(IO.read(global_config_path)).result)
      end
    end
  end
end
