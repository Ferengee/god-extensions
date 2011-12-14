#
# this patch is a solution against the over active Driver.clear_events
# PollConditions associated with the lifecycle part of the configuration
# should not be removed from the event queue.
# Instead of tracing which events need to be kept, it reschedules the associated
# conditions (lifecycle metrics <= Task.metrics[state] where state = nil)
#

module God
  class Driver
    def lifecycle_conditions
      metrics = @task.metrics[nil] unless @task.nil? || @task.metrics[nil].nil?
      metrics ||= []
      return metrics.map{|m| m.conditions}.flatten.uniq
    end
    def clear_events

      @events.clear
      lifecycle_conditions.each {|lc| schedule(lc) if lc.respond_to? :interval}
    end
  end
end