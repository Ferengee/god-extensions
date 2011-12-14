module God
  module System
    class SlashProcPoller < PortablePoller
      @@last_cpu_stats = []# // [pid] => {:run_time, :total_time}
      
      def percent_cpu
        stats = stat
        total_time = stats[:utime].to_i + stats[:stime].to_i # in jiffies
        run_time = uptime - stats[:starttime].to_i / @@hertz
        if run_time == 0
          0
        else
          delta_run_time = run_time
          delta_total_time = total_time
          @last_cpu_stat[@pid] ||=  {:run_time => 0, :total_time =>0}
          
          delta_run_time = delta_run_time -  @last_cpu_stat[@pid][:run_time]
          delta_total_time = delta_total_time -  @last_cpu_stat[@pid][:total_time]
          
          
          @last_cpu_stat[@pid][:run_time] = run_time
          @last_cpu_stat[@pid][:total_time] = total_time
          
          ((delta_total_time * 1000 / @@hertz) / delta_run_time) / 10
        end
      rescue # This shouldn't fail is there's an error (or proc doesn't exist)
        0
      end
      
    end
  end
end
