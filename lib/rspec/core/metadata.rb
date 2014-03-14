module RSpec
  module Core
    # Each ExampleGroup class and Example instance owns an instance of
    # Metadata, which is Hash extended to support lazy evaluation of values
    # associated with keys that may or may not be used by any example or group.
    #
    # In addition to metadata that is used internally, this also stores
    # user-supplied metadata, e.g.
    #
    #     describe Something, :type => :ui do
    #       it "does something", :slow => true do
    #         # ...
    #       end
    #     end
    #
    # `:type => :ui` is stored in the Metadata owned by the example group, and
    # `:slow => true` is stored in the Metadata owned by the example. These can
    # then be used to select which examples are run using the `--tag` option on
    # the command line, or several methods on `Configuration` used to filter a
    # run (e.g. `filter_run_including`, `filter_run_excluding`, etc).
    #
    # @see Example#metadata
    # @see ExampleGroup.metadata
    # @see FilterManager
    # @see Configuration#filter_run_including
    # @see Configuration#filter_run_excluding
    class Metadata < Hash

      # @api private
      #
      # @param line [String] current code line
      # @return [String] relative path to line
      def self.relative_path(line)
        line = line.sub(File.expand_path("."), ".")
        line = line.sub(/\A([^:]+:\d+)$/, '\\1')
        return nil if line == '-e:1'
        line
      rescue SecurityError
        nil
      end

      # @private
      # Used internally to build a hash from an args array.
      # Symbols are converted into hash keys with a value of `true`.
      # This is done to support simple tagging using a symbol, rather
      # than needing to do `:symbol => true`.
      def self.build_hash_from(args)
        hash = args.last.is_a?(Hash) ? args.pop : {}

        while args.last.is_a?(Symbol)
          hash[args.pop] = true
        end

        hash
      end

      class PopulatorBase
        def self.populate(metadata, parent, user_metadata, description_args)
          new(metadata, parent, user_metadata, description_args).populate
        end

        attr_reader :metadata, :parent, :user_metadata, :description_args

        def initialize(metadata, parent, user_metadata, description_args)
          @metadata         = metadata
          @parent           = parent
          @user_metadata    = user_metadata
          @description_args = description_args
        end

        def populate
          ensure_valid_user_keys

          metadata[:execution_result] = Example::ExecutionResult.new
          metadata[:description_args] = description_args
          metadata[:description]      = build_description_from(*metadata[:description_args])
          metadata[:full_description] = full_description
          metadata[:described_class]  = metadata[:describes] = described_class

          metadata[:caller] = user_metadata.delete(:caller) || caller
          metadata[:file_path], metadata[:line_number] = file_and_line_number
          metadata[:location]                          = location

          metadata.update(user_metadata)
        end

      private

        def location
          "#{metadata[:file_path]}:#{metadata[:line_number]}"
        end

        def file_and_line_number
          first_caller_from_outside_rspec =~ /(.+?):(\d+)(|:\d+)/
          return [Metadata::relative_path($1), $2.to_i]
        end

        def first_caller_from_outside_rspec
          metadata[:caller].detect {|l| l !~ /\/lib\/rspec\/core/}
        end

        def method_description_after_module?(parent_part, child_part)
          return false unless parent_part.is_a?(Module)
          child_part =~ /^(#|::|\.)/
        end

        def build_description_from(first_part = '', *parts)
          description, _ = parts.inject([first_part.to_s, first_part]) do |(desc, last_part), this_part|
            this_part = this_part.to_s
            this_part = (' ' + this_part) unless method_description_after_module?(last_part, this_part)
            [(desc + this_part), this_part]
          end

          description
        end

        def ensure_valid_user_keys
          RESERVED_KEYS.each do |key|
            if user_metadata.has_key?(key)
              raise <<-EOM.gsub(/^\s+\|/, '')
                |#{"*"*50}
                |:#{key} is not allowed
                |
                |RSpec reserves some hash keys for its own internal use,
                |including :#{key}, which is used on:
                |
                |  #{CallerFilter.first_non_rspec_line}.
                |
                |Here are all of RSpec's reserved hash keys:
                |
                |  #{RESERVED_KEYS.join("\n  ")}
                |#{"*"*50}
              EOM
            end
          end
        end
      end

      class ExamplePopulator < PopulatorBase
        def populate
          metadata[:example_group] = parent
          metadata.delete(:parent_example_group)
          metadata.delete(:example_group_block)
          super
        end

      private

        # @private
        def described_class
          metadata[:example_group][:described_class]
        end

        # @private
        def full_description
          build_description_from(metadata[:example_group][:full_description], *metadata[:description_args])
        end
      end

      class ExampleGroupPopulator < PopulatorBase
        def populate
          if parent
            metadata.update(parent)
            metadata[:parent_example_group] = parent
          end

          add_example_group_backwards_compatibility
          super
        end

      private

        # @private
        def described_class
          candidate = metadata[:description_args].first
          return candidate unless String === candidate || Symbol === candidate
          parent_group = metadata[:parent_example_group]
          parent_group && parent_group[:described_class]
        end

        # @private
        def full_description
          build_description_from(*FlatMap.flat_map(container_stack.reverse) {|a| a[:description_args]})
        end

        # @private
        def container_stack
          @container_stack ||= begin
                                 groups = [group = metadata]
                                 while group.has_key?(:parent_example_group)
                                   group = group[:parent_example_group]
                                   groups << group
                                 end
                                 groups
                               end
        end

        if Hash.method_defined?(:default_proc=)
          def add_example_group_backwards_compatibility
            metadata.default_proc = Proc.new do |hash, key|
              if key == :example_group
                RSpec.deprecate("The `:example_group` key in an example group's metadata hash",
                                :replacement => "the example group's hash directly for the " +
                                "computed keys and `:parent_example_group` to access the parent " +
                                "example group metadata")
                LegacyExampleGroupHash.new(hash)
              end
            end
          end
        else
          def add_example_group_backwards_compatibility
            metadata[:example_group] = LegacyExampleGroupHash.new(metadata)
          end
        end
      end

      def initialize(parent_group_metadata, user_metadata, *args)
        ExampleGroupPopulator.populate(self, parent_group_metadata, user_metadata, args)
      end

      # @private
      def for_example(description, user_metadata)
        metadata = dup
        ExamplePopulator.populate(metadata, self, user_metadata, [description].compact)
        metadata
      end

      RESERVED_KEYS = [
        :description,
        :example_group,
        :execution_result,
        :file_path,
        :full_description,
        :line_number,
        :location
      ]
    end

    # Mixin that makes the including class imitate a hash for backwards
    # compatibility. The including class should use `attr_accessor` to
    # declare attributes.
    # @private
    module HashImitatable
      def self.included(klass)
        klass.extend ClassMethods
      end

      def to_h
        hash = extra_hash_attributes.dup

        self.class.hash_attribute_names.each do |name|
          hash[name] = __send__(name)
        end

        hash
      end

      (Hash.public_instance_methods - Object.public_instance_methods).each do |method_name|
        next if [:[], :[]=, :to_h].include?(method_name.to_sym)

        define_method(method_name) do |*args, &block|
          issue_deprecation(method_name, *args)

          hash = to_h
          self.class.hash_attribute_names.each do |name|
            hash.delete(name) unless instance_variable_defined?(:"@#{name}")
          end

          hash.__send__(method_name, *args, &block).tap do
            # apply mutations back to the object
            hash.each do |name, value|
              if directly_supports_attribute?(name)
                set_value(name, value)
              else
                extra_hash_attributes[name] = value
              end
            end
          end
        end
      end

      def [](key)
        issue_deprecation(:[], key)

        if directly_supports_attribute?(key)
          get_value(key)
        else
          extra_hash_attributes[key]
        end
      end

      def []=(key, value)
        issue_deprecation(:[]=, key, value)

        if directly_supports_attribute?(key)
          set_value(key, value)
        else
          extra_hash_attributes[key] = value
        end
      end

    private

      def extra_hash_attributes
        @extra_hash_attributes ||= {}
      end

      def directly_supports_attribute?(name)
        self.class.hash_attribute_names.include?(name)
      end

      def get_value(name)
        __send__(name)
      end

      def set_value(name, value)
        __send__(:"#{name}=", value)
      end

      def issue_deprecation(method_name, *args)
        # no-op by default: subclasses can override
      end

      # @private
      module ClassMethods
        def hash_attribute_names
          @hash_attribute_names ||= []
        end

        def attr_accessor(*names)
          hash_attribute_names.concat(names)
          super
        end
      end
    end

    class LegacyExampleGroupHash
      include HashImitatable

      def initialize(metadata)
        @metadata = metadata
        self[:example_group] = metadata[:parent_example_group]
      end

      def to_h
        super.merge(@metadata)
      end

    private

      def directly_supports_attribute?(name)
        name != :example_group
      end

      def get_value(name)
        @metadata[name]
      end

      def set_value(name, value)
        @metadata[name] = value
      end
    end
  end
end
