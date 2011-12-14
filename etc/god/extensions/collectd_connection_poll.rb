require 'rubygems'
require 'collectd'
Collectd.add_server(interval=10, addr='10.10.10.135', port=25826)
module CollectdControl
  @@type_map = {}

  def self.getType watch
    type = @@type_map[watch]
    type ||= calculateType(watch)
    return type
  end

  def self.calculateType watch
    types = CollectdTypes.get
    type = "gauge"
    options = [watch.name, watch.group, 'service', 'gauge']
    options.each do |option|
      if types.include? option
        type = option
        break
      end

    end
    return type.to_sym
  end
  def self.update watch
    stats = Collectd.service(watch.name.to_sym)
    i = [:unmonitored, :init,  :stopped, :stopping, :stop, :start, :running,:up].index(watch.state)
    i ||= -1
    i.to_i
    stats.send(getType(watch), :state).gauge = i
  end

  def self.run
    Thread.new {

      while true
        God.watches.each do |name, w|
          self.update(w)


        end
        sleep 5

      end
    }
  end
end

module CollectdTypes
  @@types = nil
  def self.get
    @@types ||= self.init
      
    return @@types
  end
  
  private
  def self.init
    types = []
    types_dbs = ["/etc/collectd/my_types.db","/usr/share/collectd/types.db"]
    types_dbs.each do|db|
      dbf = File.new(db, "r")
      dbf.each {|line| types.push(line.split(" ").first.to_s)}
    end
    return types
  end
end

module God
  #
  # Trigger condition to send statechange to collectd
  #
  module Conditions
    class CollectStateChange < TriggerCondition
      def process(event, payload)
        CollectdControl.update(self.watch)
      end
    end
  end
  
  def self.afterload_collectd
    self.watches.each do |k,w|
      w.lifecycle do |on|
        on.condition(:collect_state_change)
      end
    end
    CollectdControl.run
  end
end
applog(nil, :info, "Loaded collectd poll connection")



