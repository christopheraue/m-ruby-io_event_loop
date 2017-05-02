describe IOEventLoop do
  subject(:instance) { IOEventLoop.new }

  it { is_expected.to be_a FiberedEventLoop }

  describe "#start" do
    subject { instance.start }

    context "when it has no timers and nothing to watch" do
      before { expect(instance).to receive(:stop).and_call_original }
      it { is_expected.to be nil }
    end

    context "when it has nothing to watch but a timer to wait for" do
      before { instance.timers.after(0.01, &callback) }
      let(:callback) { proc{} }
      before { expect(callback).to receive(:call) }

      before { expect(instance).to receive(:stop).and_call_original }
      it { is_expected.to be nil }
    end

    context "when it has an IO object waiting for a single event" do
      let(:pipe) { IO.pipe }
      let(:reader) { pipe[0] }
      let(:writer) { pipe[1] }

      context "when its waiting to be readable" do
        before { instance.timers.after(0.01) { writer.write 'Wake up!'; writer.close } }
        before { instance.await_readable(reader) }

        it { is_expected.to be nil }
        after { expect(reader.read).to eq 'Wake up!' }
      end

      context "when its waiting to be writable" do
        before { instance.await_writable(writer) }

        it { is_expected.to be nil }
        after do
          writer.write 'Hello!'; writer.close
          expect(reader.read).to eq 'Hello!'
        end
      end
    end
  end

  describe "#attach_reader and #detach_reader" do
    subject { instance.start }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    context "when watching readability" do
      before { instance.attach_reader(reader, &callback1) }
      let(:callback1) { proc{ instance.detach_reader(reader) } }

      # make the reader readable
      before { instance.timers.after(0.01) { writer.write 'Message!' } }

      before { expect(callback1).to receive(:call).and_call_original }
      it { is_expected.to be nil }
    end
  end

  describe "#attach_writer and #detach_writer" do
    subject { instance.start }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    context "when watching writability" do
      before { instance.attach_writer(writer, &callback1) }
      let(:callback1) { proc{ instance.detach_writer(writer) } }

      before { expect(callback1).to receive(:call).and_call_original }
      it { is_expected.to be nil }
    end
  end

  describe "#await with timeout" do
    subject { instance.await(:id, within: 0.02, timeout_result: IOEventLoop::TimeoutError.new("Time's up!")) }

    context "when the result arrives in time" do
      before { instance.timers.after(0.01) { instance.resume(:id, :result) } }
      it { is_expected.to be :result }
    end

    context "when evaluation of result is too slow" do
      it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
    end
  end

  describe "#await_readable" do
    subject { instance.await_readable(reader, opts) }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    shared_examples "for readability" do
      context "when readable after some time" do
        before { instance.timers.after(0.01) { writer.write 'Wake up!' } }

        before { instance.timers.after(0.005) { expect(instance.awaits_readable? reader).to be true } }
        it { is_expected.to be :readable }
        after { expect(instance.awaits_readable? reader).to be false }
      end

      context "when cancelled" do
        before { instance.timers.after(0.01) { instance.cancel_awaiting_readable reader } }

        before { instance.timers.after(0.005) { expect(instance.awaits_readable? reader).to be true } }
        it { is_expected.to be :cancelled }
        after { expect(instance.awaits_readable? reader).to be false }
      end
    end

    context "when it waits indefinitely" do
      let(:opts) { { within: nil, timeout_result: nil } }

      include_examples "for readability"

      context "when never readable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:opts) { { within: 0.02, timeout_result: IOEventLoop::TimeoutError.new("Time's up!") } }

      include_examples "for readability"

      context "when not readable in time" do
        it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
      end
    end
  end

  describe "#await_writable" do
    subject { instance.await_writable(writer, opts) }

    let(:pipe) { IO.pipe }
    let(:reader) { pipe[0] }
    let(:writer) { pipe[1] }

    # jam pipe: default pipe buffer size on linux is 65536
    before { writer.write('a' * 65536) }

    shared_examples "for writability" do
      context "when writable after some time" do
        before { instance.timers.after(0.01) { reader.read(65536) } } # clear the pipe

        before { instance.timers.after(0.005) { expect(instance.awaits_writable? writer).to be true } }
        it { is_expected.to be :writable }
        after { expect(instance.awaits_writable? writer).to be false }
      end

      context "when cancelled" do
        before { instance.timers.after(0.01) { instance.cancel_awaiting_writable writer } }

        before { instance.timers.after(0.005) { expect(instance.awaits_writable? writer).to be true } }
        it { is_expected.to be :cancelled }
        after { expect(instance.awaits_writable? writer).to be false }
      end
    end

    context "when it waits indefinitely" do
      let(:opts) { { within: nil, timeout_result: nil } }

      include_examples "for writability"

      context "when never writable" do
        # we do not have enough time to test that
      end
    end

    context "when it has a timeout" do
      let(:opts) { { within: 0.02, timeout_result: IOEventLoop::TimeoutError.new("Time's up!") } }

      include_examples "for writability"

      context "when not writable in time" do
        it { is_expected.to raise_error IOEventLoop::TimeoutError, "Time's up!" }
      end
    end
  end
end