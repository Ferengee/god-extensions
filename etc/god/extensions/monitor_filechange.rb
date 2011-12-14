# depends sinotify gem
require 'rubygems'
require 'sinotify'

module God
  def self.afterload_filechange
    FileChangeEvents.run
  end

  module FileChangeEvents
    @@registered_files = {}

    def self.register file, &block
      @@registered_files[file] = block
    end
      
    def self.deregister file
      @@registered_files[file] = nil
    end

    def self.addFile file
      @@registered_files[file] ||= nil
    end

    def self.notify(sinotify_event)
      file = sinotify_event.path
      callback = @@registered_files[file]
      unless callback.nil?
        callback.call(sinotify_event.etypes, file)
      end
    end

    def self.run 
      @@registered_files.keys.map{|file| File.dirname(file) }.uniq.each do |folder|
        notifier = Sinotify::Notifier.new(folder, :recurse => false,  :etypes => [:create, :modify, :delete])
        notifier.on_event do |sinotify_event|
          FileChangeEvents.notify(sinotify_event)
        end
        notifier.watch!
      end
    end
  end


  module Conditions
    class PidfileChanged < EventCondition

      def initialize
        self.info = "Got a change in my pid file"
      end

      def valid?
        true
      end

      def register
        FileChangeEvents.register(self.watch.pid_file) do |method, file|
          self.watch.trigger(self) unless method.include? :delete
        end
        msg = "#{self.watch.name} registered 'PidfileChanged' event"
        applog(self.watch, :info, msg)
      end

      def deregister
        FileChangeEvents.deregister(self.watch.pid_file)
        msg = "#{self.watch.name} deregistered 'PidfileChanged' event"
        applog(self.watch, :info, msg)
      end
    end
  end

  class Watch < Task

    def pid_file= pid_file
      FileChangeEvents.addFile pid_file
      @process.pid_file = pid_file
    end
  end

end