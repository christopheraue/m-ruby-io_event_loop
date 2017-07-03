class Stage
  def gc_disabled
    GC.start
    GC.disable
    yield
  ensure
    GC.enable
  end

  def execute(opts = {})
    seconds = opts[:seconds] || 1
    event_loop = Concurrently::EventLoop.current
    event_loop.reinitialize!
    iterations = 0
    start_time = event_loop.lifetime
    end_time = start_time + seconds
    while event_loop.lifetime < end_time
      yield
      iterations += 1
    end
    stop_time = event_loop.lifetime
    { iterations: iterations, time: (stop_time-start_time) }
  end

  def measure(opts = {}) # &test
    gc_disabled do
      execute(opts){ yield }
    end
  end
end

stage = Stage.new
format = "  %-25s %7d executions in %2.4f seconds"
factor = ARGV.fetch(0, 1).to_i

puts <<-DOC
Benchmarked Code
----------------
  conproc = concurrent_proc{ wait 0 }
  
  while elapsed_seconds < 1
    #{factor}.times{ # CODE # }
    wait 0 # to enter the event loop
  end

Results
-------
  # CODE #
DOC

conproc = concurrent_proc{ wait 0 }

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call }
  # no need to enter the event loop manually. It already happens in #call
end
puts sprintf(format, "conproc.call:", factor*result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call_nonblock }
  wait 0
end
puts sprintf(format, "conproc.call_nonblock:", factor*result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call_detached }
  wait 0
end
puts sprintf(format, "conproc.call_detached:", factor*result[:iterations], result[:time])

result = stage.measure(seconds: 1) do
  factor.times{ conproc.call_and_forget }
  wait 0
end
puts sprintf(format, "conproc.call_and_forget:", factor*result[:iterations], result[:time])