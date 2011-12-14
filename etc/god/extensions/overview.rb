
require "drb"
class Machine
  attr_reader :hostname, :ip_address
  attr_writer :hostname

  def initialize ip_address="127.0.0.1", hostname=""
    DRb.start_service("druby://127.0.0.1:0")
    @ip_address = ip_address
    @hostname = hostname
    @connection =  DRbObject.new(nil, God::Socket.socket(God::DRB_PORT_DEFAULT))
    #@connection = DRbObject.new(nil, "druby://#{ip_address}:#{God::DRB_PORT_DEFAULT}")
    @status = nil
    @last = Time.now
  end

  def status

    if @status.nil? || (@last - Time.now <  -5)
      begin
        @status = @connection.status
      rescue
        @status = {}
        raise "Druby connection to #{@ip_address} is broken"
      end
      @last = Time.now
    end
    @status
  end

  def groups
    result = {}
    status.each do |service, value|
      group = value[:group]
      group ||= :nil
      result[group] ||=[]
      value[:name] = service
      result[group].push value
    end
    return result
  end

  # health is defined as enum :red :yellow :green
  # red is all red
  # green is all green
  # yellow any other case


  def group_health group
    group_status = groups[group]
    service_health group_status
  end

  #heck all services
  def overall_health
    service_health status.values
  end

  def service_health services_status
    return :red if services_status.every {|service| service[:health] == :red }
    return :green if services_status.every {|service| service[:health] == :green }
    return :yellow
  end
  #returns all services that have a yellow or red health
  def not_green
    result = []
    status.each {|name, value|
      value[:name] = name
      result << value if value[:health] != :green
    }
    result
  end
end

class Overview
  attr_reader :machines
  def initialize
    @machines = []
  end

  def machine_names
    @machines.map {|m| m.hostname}
  end

  def machine_ip_addresses
    @machines.map {|m| m.ip_address}
  end

  def find_machine_by_ip_address(address)
    @machines.reject {|x| x.ip_address != address }.first
  end

  def find_machine_by_name(name)
    @machines.reject {|x| x.hostname != name }.first
  end

  def status

    groups = {}
    services = {}
    overall_health = {}
    offline = []
    #declaring variables outside of the loop scope speeds things up a bit.

    machine = hostname = status = group = service = nil
    for machine in @machines do
      hostname = machine.hostname
      next unless machine.respond_to? :status
      begin
        status = machine.status
        overall_health[hostname] = machine.overall_health
      rescue Exception => e
        offline << machine
        status = {}
        puts e
      end

      for service in status.keys do
        services[service] ||= {}
        services[service][hostname] = status[service]

        group = status[service][:group]
        unless group.nil?
          groups[group] ||= {}
          groups[group][hostname] = machine.group_health group
        end
      end
    end
    {:services => services, :groups => groups, :offline => offline, :machines => overall_health}
  end
end