module God
  module Conditions
    class InterfaceIsUp < PollCondition
      attr_accessor :running

      def initialize
        super
       # self.running = true
      end

      def test
        interface = self.watch.name.sub("interface_","")
        is_up = `/sbin/ifconfig`.reject {|line| !line.match(/#{interface}\s/) }.length > 0
        if is_up
          self.info = "We are up #{self.watch.name}"
        else
          self.info = "We are down #{self.watch.name}"
        end
        self.running ? is_up : !is_up

      end
    end
    class XIsUp  < PollCondition
      attr_accessor :running, :is_up
      def test
        r = @is_up.call
        up = !r.nil? && r != false
        if up
          self.info = "We are up #{self.watch.name}"
        else
          self.info = "We are down #{self.watch.name}"
        end
        result = self.running ? up : !up
        puts "returning #{result} with #{self.running}"
        result
      end
    end

    class O2cbIsUp < XIsUp
      def initialize
        super
        @is_up = Proc.new { `/etc/init.d/o2cb status`.downcase.match(/online/) }
      end
    end

    class Ocfs2IsUp < XIsUp
      def initialize
        super
        @is_up = Proc.new { `/etc/init.d/o2cb status`.downcase.match(/heartbeat:\s?(.*) active/)[1] == "" }
      end
    end
  end
end