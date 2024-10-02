# Platform specific implementations of Interception.start and Interception.stop
class << Interception
  private

  # For Rubinius we just monkeypatch Kernel#raise_exception,
  #
  # This is normally a thin wrapper around raising an exception on the VM
  # (so the layer of abstraction below Kernel#raise).
  if defined? Rubinius

    def start
      class << Rubinius

        alias raise_with_no_interception raise_exception

        def raise_exception(exc)
          bt = Rubinius::VM.backtrace(1, true).drop_while do |x|
            x.variables.method.file.to_s.start_with?("kernel/")
          end.first
          b = Binding.setup(bt.variables, bt.variables.method, bt.constant_scope, bt.variables.self, bt)

          Interception.rescue(exc, b)
          raise_with_no_interception(exc)
        end
      end
    end

    def stop
      class << Rubinius
        alias raise_exception raise_with_no_interception
      end
    end

  # For MRI
  # @note For Ruby 2.0 and later we use the new TracePoint API.
  elsif RUBY_VERSION.to_f >= 2.0 && (%w[ruby jruby].include? RUBY_ENGINE)

    def start
      @tracepoint ||= TracePoint.new(:raise) do |tp|
        self.rescue(tp.raised_exception, tp.binding)
      end

      @tracepoint.enable
    end

    def stop
      @tracepoint.disable
    end

  # For old MRI
  else

    require File.expand_path('../../ext/interception', __FILE__)

  end
end
