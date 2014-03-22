module RSpec
  module Core
    # Shared examples let you describe behaviour of types or modules.
    # When declared, a shared group's content is stored.
    # It is only realized in the context of another example group,
    # which provides any context the shared group needs to run.
    module SharedExampleGroup
      # @overload shared_examples(name, &block)
      # @overload shared_examples(name, tags, &block)
      #
      # Stores the block for later use. The block will be evaluated
      # in the context of an example group via `include_examples`,
      # `include_context`, or `it_behaves_like`.
      #
      # @option name [String] to match when looking up this shared group
      # @param block The block to be eval'd
      #
      # @example
      #
      #   shared_examples "auditable" do
      #     it "stores an audit record on save!" do
      #       lambda { auditable.save! }.should change(Audit, :count).by(1)
      #     end
      #   end
      #
      #   class Account do
      #     it_behaves_like "auditable" do
      #       def auditable; Account.new; end
      #     end
      #   end
      #
      # @see ExampleGroup.it_behaves_like
      # @see ExampleGroup.include_examples
      # @see ExampleGroup.include_context
      def shared_examples(*args, &block)
        top_level = self == ExampleGroup
        if top_level && RSpec.thread_local_metadata[:in_example_group]
          raise "Creating isolated shared examples from within a context is " +
                "not allowed. Remove `RSpec.` prefix or move this to a " +
                "top-level scope."
        end
        RSpec.world.shared_example_group_registry.add_group(self, *args, &block)
      end

      alias_method :shared_context,      :shared_examples
      alias_method :share_examples_for,  :shared_examples
      alias_method :shared_examples_for, :shared_examples

      # @api private
      #
      # Shared examples top level DSL
      module TopLevelDSL
        # @private
        def self.definitions
          proc do
            def shared_examples(*args, &block)
              RSpec.world.shared_example_group_registry.add_group(:main, *args, &block)
            end

            alias :shared_context      :shared_examples
            alias :share_examples_for  :shared_examples
            alias :shared_examples_for :shared_examples
          end
        end

        # @private
        def self.exposed_globally?
          @exposed_globally ||= false
        end

        # @api private
        #
        # Adds the top level DSL methods to Module and the top level binding
        def self.expose_globally!
          return if exposed_globally?
          Core::DSL.change_global_dsl(&definitions)
          @exposed_globally = true
        end

        # @api private
        #
        # Removes the top level DSL methods to Module and the top level binding
        def self.remove_globally!
          return unless exposed_globally?

          Core::DSL.change_global_dsl do
            undef shared_examples
            undef shared_context
            undef share_examples_for
            undef shared_examples_for
          end

          @exposed_globally = false
        end

      end

      # @private
      #
      # Used internally to manage the shared example groups and
      # constants. We want to limit the number of methods we add
      # to objects we don't own (main and Module) so this allows
      # us to have helper methods that don't get added to those
      # objects.
      class Registry
        def add_group(context, *args, &block)
          ensure_block_has_source_location(block, CallerFilter.first_non_rspec_line)

          if key? args.first
            key = args.shift
            warn_if_key_taken context, key, block
            add_shared_example_group context, key, block
          end

          unless args.empty?
            mod = Module.new
            (class << mod; self; end).__send__(:define_method, :included) do |host|
              host.class_exec(&block)
            end
            RSpec.configuration.include mod, *args
          end
        end

        def find(lookup_contexts, name)
          lookup_contexts.each do |context|
            found = shared_example_groups[context][name]
            return found if found
          end

          shared_example_groups[:main][name]
        end

        # @api private
        def shared_example_groups
          @shared_example_groups ||= Hash.new { |hash, context| hash[context] = {} }
        end

      private

        def add_shared_example_group(context, key, block)
          shared_example_groups[context][key] = block
        end

        def key?(candidate)
          [String, Symbol, Module].any? { |cls| cls === candidate }
        end

        def warn_if_key_taken(context, key, new_block)
          return unless existing_block = shared_example_groups[context][key]

          RSpec.warn_with <<-WARNING.gsub(/^ +\|/, ''), :call_site => nil
            |WARNING: Shared example group '#{key}' has been previously defined at:
            |  #{formatted_location existing_block}
            |...and you are now defining it at:
            |  #{formatted_location new_block}
            |The new definition will overwrite the original one.
          WARNING
        end

        def formatted_location(block)
          block.source_location.join ":"
        end

        if Proc.method_defined?(:source_location)
          def ensure_block_has_source_location(block, caller_line); end
        else # for 1.8.7
          def ensure_block_has_source_location(block, caller_line)
            block.extend Module.new {
              define_method :source_location do
                caller_line.split(':')
              end
            }
          end
        end
      end
    end
  end

  instance_exec(&Core::SharedExampleGroup::TopLevelDSL.definitions)
end
