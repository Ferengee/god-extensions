module God
 
  module System
    class Process
      # return pid and all its childrens pid
      
      def self.parent_and_children(pid)
        @poller = self.fetch_system_poller.new(pid)

        children = @poller.children()
        puts "children: #{children.join(" ")}" if(children.length)
        children.push(pid)
        children.map do |cpid|
          System::Process.new(cpid)
        end
      end
    end
    
    class PortablePoller
      def children
        `ps --ppid #{@pid}`.map{ |l| l.split()[0]}.reject {|i| i.nil? }[1..-1]
      end
    end
    
#      class SlashProcPoller < PortablePoller
#        def children pid
#          Dir.entries('/proc/').reject
#          { |s| 
#             s.to_i == 0 
#          }.reject 
#          { |i|  
#            File.read("/proc/#{i}/stat").split[3] != pid
#          }
#        end
#      end

  end
  module Conditions

    class CpuUsage < PollCondition
      def test
        
        processes = System::Process.parent_and_children(self.pid)
        percent_cpu = 0
        processes.each do |process|
          percent_cpu += process.percent_cpu
        end
        @timeline.push(percent_cpu)
        
        history = "[" + @timeline.map { |x| "#{x > self.above ? '*' : ''}#{x}%%" }.join(", ") + "]"
        
        if @timeline.select { |x| x > self.above }.size >= self.times.first
          self.info = "cpu out of bounds #{history}"
          return true
        else
          self.info = "cpu within bounds #{history}"
          return false
        end
      end
      
    end
    
    class MemoryUsage < PollCondition
      def test
        processes = System::Process.parent_and_children(self.pid)
        memory = 0
        processes.each do |process|
          memory += process.memory
        end
        @timeline.push(memory)
        
        history = "[" + @timeline.map { |x| "#{x > self.above ? '*' : ''}#{x}kb" }.join(", ") + "]"
        
        if @timeline.select { |x| x > self.above }.size >= self.times.first
          self.info = "memory out of bounds #{history}"
          return true
        else
          self.info = "memory within bounds #{history}"
          return false
        end
      end
    end
  end
end
