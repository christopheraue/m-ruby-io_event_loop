module Concurrently
  class EventLoop
    def self.current
      Thread.current.__concurrently_event_loop__
    end

    time_module = Module.new do
      def reinitialize!
        @clock = Hitimes::Interval.new.tap(&:start)
        super
      end

      def lifetime
        @clock.to_f
      end
    end

    prepend time_module
  end
end