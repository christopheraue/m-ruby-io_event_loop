module AggregatedTimers
  class Timer
    def initialize(seconds, opts = {}, &callback)
      raise Error, 'no block given' unless callback
      @seconds = seconds || @seconds
      @repeat = opts.fetch(:repeat, @repeat) || false
      @callback = callback || @callback
      @collection = opts[:collection]
      repeat opts.fetch(:start_time, WallClock.now)
    end

    def repeat(start_time = WallClock.now)
      raise Error, 'timer still running' if @timeout_time
      @timeout_time = start_time + @seconds
      @collection.schedule(self) if @collection
      true
    end

    def trigger
      raise Error, 'timer canceled' unless @timeout_time
      @callback.call
      old_timeout_time = @timeout_time
      cancel
      repeat(old_timeout_time) if @repeat
      true
    end

    def cancel
      @timeout_time = nil
      true
    end

    attr_reader :seconds

    attr_reader :timeout_time

    def waiting_time
      if @timeout_time
        waiting_time = @timeout_time - WallClock.now
        waiting_time < 0 ? 0 : waiting_time
      end
    end

    def repeats?
      @repeat
    end

    def canceled?
      not waiting_time
    end

    def >(timer)
      @timeout_time > timer.timeout_time
    end

    def inspect
      "#<#{self.class}:0x#{'%014x' % __id__} #{waiting_time ? "waits another #{waiting_time.round(3)} seconds" : 'CANCELED'}>"
    end
  end
end