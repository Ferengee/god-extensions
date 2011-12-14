
module God
  # Added health to status
  def self.status
    info = {}
    self.watches.map do |name, w|
      health, reason = w.health
      info[name] = {:state => w.state, :group => w.group, :health => health, :reason => reason }
    end
    info
  end
  #adding health to Watch
  class Watch
    # :red, :yellow, :green
    #
    # A block can be set in any watch to determine the health of that watch
    # This block may give the following result:
    # a symbol signaling the health
    #   :red | :yellow | :green
    # or an array of length 2:
    #   [:red | :yellow | :green, "descriptive reason of the health"]
    #

    def health &block
      if block_given?
        @health_block = block
      else
        if @health_block.nil?
          self.state == :up ? :green : [:red, "Not Up!"]
        else
          @health_block.call(self)
        end
      end
    end
  end

  #
  # Commandline aanpassingen werken alleen als God zelf gepatched wordt
  # Deze worden standaard niet mee geladen als "god status" vanuit de shell
  # aangeroepen wordt
  #

  module CLI
    class Command
      def status_command
        exitcode = 0
        statuses = @server.status
        groups = {}
        statuses.each do |name, status|
          g = status[:group] || ''
          groups[g] ||= {}
          groups[g][name] = status
        end

        if item = @args[1]
          if single = statuses[item]
            # specified task (0 -> up, 1 -> unmonitored, 2 -> other)
            state = single[:state]
            puts "#{item}: #{state}"
            exitcode = state == :up ? 0 : (state == :unmonitored ? 1 : 2)
          elsif groups[item]
            # specified group (0 -> up, N -> other)
            puts "#{item}:"
            groups[item].keys.sort.each do |name|
              state = groups[item][name][:state]
              health = groups[item][name][:health]
              print "  "
              puts "#{name}: #{state}" "#{health}"
              exitcode += 1 unless state == :up
            end
          else
            puts "Task or Group '#{item}' not found."
            exit(1)
          end
        else
          # show all groups and watches
          groups.keys.sort.each do |group|
            puts "#{group}:" unless group.empty?
            groups[group].keys.sort.each do |name|
              state = groups[group][name][:state]
              print "  " unless group.empty?
              puts "#{name}: #{state}"
            end
          end
        end

        exit(exitcode)
      end
    end
  end
end
