module God
  module System
    class SlashProcPoller < PortablePoller
      def virt_memory
        stat[:virt].to_i * @@kb_per_page
      rescue # This shouldn't fail is there's an error (or proc doesn't exist)
        0
      end
    end

    class PortablePoller
      def virt_memory
        ps_int('virt')
      end
    end

    class Process
      def virt_memory
        @poller.virt_memory
      end
    end
  end
  module Conditions
    class VirtMemoryUsage < MemoryUsage
      def test
        process = System::Process.new(self.pid)
        @timeline.push(process.virt_memory)

        history = "[" + @timeline.map { |x| "#{x > self.above ? '*' : ''}#{x}kb" }.join(", ") + "]"

        if @timeline.select { |x| x > self.above }.size >= self.times.first
          self.info = "virtual memory out of bounds #{history}"
          return true
        else
          self.info = "virtual memory within bounds #{history}"
          return false
        end
      end
    end
  end
end