# typed: false
module Datadog
  module Profiling
    module Ext
      # Monkey patches `Kernel#fork`, adding a `Kernel#at_fork` callback mechanism which is used to restore
      # profiling abilities after the VM forks.
      module Forking
        def self.supported?
          Process.respond_to?(:fork)
        end

        def self.apply!
          return false unless supported?

          modules = [::Process, ::Kernel]
          # TODO: Ruby < 2.3 doesn't support Binding#receiver.
          #       Remove "else #eval" clause when Ruby < 2.3 support is dropped.
          # NOTE: Modifying the "main" object as we do here is (as far as I know) irreversible. During tests, this change
          #       will stick around even if we otherwise stub `Process` and `Kernel`.
          modules << (TOPLEVEL_BINDING.respond_to?(:receiver) ? TOPLEVEL_BINDING.receiver : TOPLEVEL_BINDING.eval('self'))

          # Patch top-level binding, Kernel, Process.
          # NOTE: We could instead do Kernel.module_eval { def fork; ... end }
          #       however, this method rewrite is more invasive and irreversible.
          #       It could also have collisions with other libraries that patch.
          #       Opt to modify the inheritance of each relevant target instead.
          modules.each do |mod|
            clazz = if mod.class <= Module
                      mod.singleton_class
                    else
                      mod.class
                    end

            clazz.prepend(Kernel)
          end
        end

        # Extensions for kernel
        module Kernel
          FORK_STAGES = [:prepare, :parent, :child].freeze

          def fork
            # If a block is provided, it must be wrapped to trigger callbacks.
            child_block = if block_given?
                            proc do
                              # Trigger :child callback
                              at_fork_blocks[:child].each(&:call) if at_fork_blocks.key?(:child)

                              # Invoke original block
                              yield
                            end
                          end

            # Trigger :prepare callback
            at_fork_blocks[:prepare].each(&:call) if at_fork_blocks.key?(:prepare)

            # Start fork
            # If a block is provided, use the wrapped version.
            result = child_block.nil? ? super : super(&child_block)

            # Trigger correct callbacks depending on whether we're in the parent or child.
            # If we're in the fork, result = nil: trigger child callbacks.
            # If we're in the parent, result = fork PID: trigger parent callbacks.
            # rubocop:disable Style/IfInsideElse
            if result.nil?
              # Trigger :child callback
              at_fork_blocks[:child].each(&:call) if at_fork_blocks.key?(:child)
            else
              # Trigger :parent callback
              at_fork_blocks[:parent].each(&:call) if at_fork_blocks.key?(:parent)
            end
            # rubocop:enable Style/IfInsideElse

            # Return PID from #fork
            result
          end

          def at_fork(stage = :prepare, &block)
            raise ArgumentError, 'Bad \'stage\' for ::at_fork' unless FORK_STAGES.include?(stage)

            at_fork_blocks[stage] = [] unless at_fork_blocks.key?(stage)
            at_fork_blocks[stage] << block
          end

          module_function

          def at_fork_blocks
            # Blocks should be shared across all users of this module,
            # e.g. Process#fork, Kernel#fork, etc. should all invoke the same callbacks.
            # rubocop:disable Style/ClassVars
            @@at_fork_blocks ||= {}
            # rubocop:enable Style/ClassVars
          end
        end
      end
    end
  end
end
