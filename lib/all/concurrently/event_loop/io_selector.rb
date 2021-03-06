module Concurrently
  # @private
  class EventLoop::IOSelector
    def initialize(event_loop)
      @run_queue = event_loop.run_queue
      @readers = {}
      @writers = {}
      @evaluations = {}
    end

    def awaiting?
      @evaluations.size > 0
    end

    def await_reader(io, evaluation)
      @readers[evaluation] = io
      @evaluations[io] = evaluation
    end

    def await_writer(io, evaluation)
      @writers[evaluation] = io
      @evaluations[io] = evaluation
    end

    def cancel_reader(io)
      @readers.delete @evaluations.delete io
    end

    def cancel_writer(io)
      @writers.delete @evaluations.delete io
    end

    def process_ready_in(waiting_time)
      waiting_time = nil if waiting_time == Float::INFINITY
      if selected = IO.select(@readers.values, @writers.values, nil, waiting_time)
        selected.each do |ios|
          ios.each{ |io| @run_queue.resume_evaluation! @evaluations[io], true }
        end
      end
    end
  end
end