#
# an extention to allow state changes to be triggered by external events
# used with handle_notifcation.rb it can be coupled with collectd's thresholds
#
module God

  module ExternalEvents
    @@registered_conditions = {}
    def self.register condition, &block
      if !block_given?
        block = Proc.new {|event|
          condition.watch.trigger(condition) if condition.signal_on == event
        }
      end
      @@registered_conditions[condition] = block

    end
    def self.deregister condition
      @@registered_conditions.delete condition
    end
    def self.external_event event
      for block in @@registered_conditions.values do
        block.call(event)
      end
    end
  end
  def self.external_event event
    ExternalEvents.external_event event
  end

  module Conditions
    #
    # Abusing Event condition, because we are not going to register with
    # the default system event handler
    # we use our own external event source
    # TODO: build a real eventhandler in the system in the same design philosophy
    # as god already uses for netlink etc
    # 1) write a new implementation of Condition
    # 2) patch Condition to accept our new Condition decendant
    #
    
    class ExternalSignal < EventCondition
      attr_accessor :signal_on

      def initialize
        self.info = "Got a signal"
        @extra_conditions = []
      end

      def valid?
        true
      end

      def register
        ExternalEvents.register(self) do |event|
          @signal_on ||= {}
          trigger = true
          for key in @signal_on.keys do
            if Array(@signal_on[key]).index(event[key]).nil?
              trigger = false
            end
          end

          if trigger && extra_condition_test
            self.watch.trigger(self)
          end
        end
        msg = "#{self.watch.name} registered 'net_signal' event"
        applog(self.watch, :info, msg)
      end

      def deregister
        ExternalEvents.deregister(self)
        msg = "#{self.watch.name} deregistered 'net_signal' event"
        applog(self.watch, :info, msg)
      end

      def in_case_of extra_condition
          #@extra_conditions ||= []
          condition = Condition.generate(extra_condition, self.watch)
          @extra_conditions.push condition
          yield condition if block_given?
      end
      def extra_condition_test
        puts "testing the extra"
        result = true
        for condition in @extra_conditions do
          result = condition.test if condition.respond_to? :test
          break if result == false
        end
        return result
      end
    end
  end
end
#puts "external events loaded"
#puts (p God::Conditions::ExternalSignal.new)
#puts "tested"