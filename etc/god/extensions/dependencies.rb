class Array
  def any &block
    self.map(&block).any?
  end
  def every &block
    self.map(&block).all?
  end
end
module God
  @@watch_dependencies = []
  def self.add_watch_dependencies dependencies
    puts "add_watch_dependencies called #{dependencies.inspect}"
    @@watch_dependencies = @@watch_dependencies | dependencies
    puts "  #{@@watch_dependencies.inspect}"
  end
  #TODO: move to more general patch
  def self.load(glob)
    puts "loading code"
    Dir[glob].each do |f|
      Kernel.load f
    end
    after_load = self.methods.reject {|m| m.index("afterload_") != 0}
    after_load.each {|m| self.send(m.to_sym)}
  end

  def self.afterload_dependencies
    # after loading the config files
    # add dependency watches
    puts "adding lifcycle conditions: for #{@@watch_dependencies.length} items"
    for dependency in @@watch_dependencies do
      w = God.watches[dependency.to_s]
      if w.nil?
        puts "no watch found for: #{dependency.to_s}"
      else
        puts "#{w.name}"
        w.lifecycle do |on|
          on.condition(:notify_my_state_change)
        end
      end
    end
    

  end
  module Behaviors
    
    class CheckDependencies < Behavior
  
      def before_start
        "nothing"
      end
      
      def before_stop
      	stopped = ""
      	name = self.watch.name
      	self.watch.move(:stopping)
        #      	puts "state: #{watch.state}"
        node = Dependencies.reverse_dependencies[name.to_sym]
        stop_grace = 0;
        unless node.nil?
          for dependency in node.dependencies do
            stopping = dependency.name.to_s
            w = God.watches[stopping]
            unless w.nil?
              w.action(:stop)
              w.move(:init)
              stop_grace = [stop_grace, w.stop_grace].max
            end
            stopped +=  stopping
          end
        end
        sleep(stop_grace)
        "#{name} stopped reverse dependencies: #{stopped}"
      end
    
      def after_stop
      	self.watch.move(:stopped)

        "after stop: #{self.watch.name}"
      end
  
    end
   
  end
  module Conditions
    class NotifyMyStateChange < TriggerCondition
      def process(event, payload)
        puts "NotifyMyStateChange:process: #{self.watch.name}:#{event}:#{payload.join(', ')}:"
        if event == :state_change
          event_from_state, event_to_state = *payload
          begin
            ExternalEvents.external_event :event => event, :from => event_from_state, :to => event_to_state
          rescue Exception => e
            puts p e
          end
        end
      end

      def method_missing name, *args
        puts "NotifyMyStateChange:mm #{name} #{p args}"
      end
    end

    class DependenciesRunning < PollCondition
      attr_accessor :dependencies_running
      def initialize
        super
        self.dependencies_running = true
      end
      #The test is inverted if dependencies_running is false
      def test
        self.info = "Not all dependencies running"
        result = false
        if(self.dependencies_running)
          result = self.watch.dependencies.every { |x|
            #puts "dependency:#{x}:"
            !God.watches[x.to_s].nil? && God.watches[x.to_s].state == :up
          }
          self.info = "All dependencies running" if result
        else
          result = self.watch.dependencies.any { |x| !God.watches[x.to_s].nil? && God.watches[x.to_s].state != :up }
        end
        return result
      end
    end

  end


  class Dependencies
    
    @@forward_dependencies = DependencyGraph.new
    @@reverse_dependencies = DependencyGraph.new

    def self.reverse_dependencies
      @@reverse_dependencies.nodes
    end
    
    def self.dependencies
      @@forward_dependencies.nodes
    end
    
    def self.add(a,b)
      @@forward_dependencies.add(a,b)
      @@reverse_dependencies.add(b,a)
      if cyclic_dependency(a)
        applog(self, :info, "Cyclic dependency detected for #{a}")
        sleep 1
        Process.exit
      end
    end

    def self.cyclic_dependency(a)
      node = @@forward_dependencies.nodes[a]
      node.dependencies.any { |x| x.has_node?(node) }
    end
  end

  class Watch
    remove_const(:VALID_STATES)
    VALID_STATES = [:init, :running, :up, :start, :restart, :stop, :stopping, :stopped]

    # def pid
    #   File.read(self.pid_file).strip.to_i
    #  end
    #
    # one or more watch names as dependency
    # w.dependencies :myslqd, :ocfs2
    #
    attr_accessor :options

    # Enable monitoring
    def monitor
      # start monitoring at the first available of the init or up states
      if !self.metrics[:init].empty?
        started = []
        @dependencies.each do |dependency|
          to_start = dependency.to_s
          w =  God.watches[to_start]
          unless (w.state == :up)
            w.move(:init)
            started << to_start
          end
        end
        "puts send start to dependencies: #{started.join(", ")}"
        self.move(:init)
      else
        self.move(:up)
      end
    end
    
    attr_reader :dependencies
    def prepare *args
      super *args 
      self.behavior(:check_dependencies)
      @dependencies ||= []
      self.metrics[:stopping] ||= []
      self.metrics[:stopped] ||= []
      for dependency in @dependencies do
        Dependencies.add(self.name.to_sym, dependency)
      end
    end
    ##
    # As soon as a watch has dependencies added to itself
    # we add a transition to the watch which allows the watch to start
    # only if the dependency is running
    ##
    def dependencies= dependencies
      @options ||= {}
      process_running = @options[:process_running]
      process_running ||=:process_running
      
    
      @dependencies = Array(dependencies)

      #
      # if we have dependencies then our health depends on them
      #
      #[:init, :start].include? w.state
      self.health {|w|
        if [:stopped, :stopping].include? w.state
        [:unknown]
        elsif w.state == :init
        [:red, "Waiting for dependencies to come up."]
         elsif w.state == :start
        [:red, "Trying to start."]

        elsif w.state == :up
        [:green]
        elsif w.state == :running
        [:yellow, "Not all dependencies are running"]
        end
      }

      # Just in case everyone was already started before god
      # went up
      # its nice to check once and a while if we should start even if we didn't
      # get the memo
      self.transition(:init,  :start) do |on|
        on.condition(:complex) do |service|
          service.and(:dependencies_running) do |c|
            c.dependencies_running = true
          end
          service.and(process_running) do |c|
            c.running = false
          end
          service.interval = 300
        end
      end

      self.transition([:stopped, :init],  :running) do |on|
        on.condition(:complex) do |service|
          service.and(process_running) do |c|
            c.running = true
          end
          service.interval = 120
        end
      end
       self.transition(:running,  :up) do |on|
        on.condition(:dependencies_running) do |c|
            c.dependencies_running = true
            c.interval = 5
          end
      end

      self.transition(:stopped,  :init) do |on|
        on.condition(:pidfile_changed)
      end

      self.transition(:init, :start) do |on|
        on.condition(:external_signal) do |es|
          es.signal_on = { :event => :state_change, :to => [:start, :up] }
          es.in_case_of(:dependencies_running)
          es.in_case_of(process_running) do |c|
            c.running = false
          end
        end
      end

      self.transition([:up, :init], :stop) do |on|
        on.condition(:external_signal) do |es|
          es.signal_on = { :event => :state_change, :to => :init }
          es.in_case_of(:dependencies_running) do |c|
            c.dependencies_running = false
          end
          es.in_case_of(process_running) do |c|
            c.running = true
          end
        end
      end

      self.transition(:up, :init) do |on|
        on.condition(:process_exits)
      end

      self.transition(:up, :init) do |on|
        on.condition(process_running) do |c|
          c.running = false
          c.interval = 120
        end
      end

      self.transition(:stop,  :init) do |on|
        on.condition(process_running) do |c|
          c.running = false
        end
      end

      God.add_watch_dependencies @dependencies


    end
  end

end