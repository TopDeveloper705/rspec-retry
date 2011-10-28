# Builds command line arguments to pass to the rspec command over DRb
class RSpec::Core::DrbOptions
  def initialize(submitted_options)
    @submitted_options = submitted_options
  end

  def options
    argv = []
    argv << "--color"        if @submitted_options[:color_enabled]
    argv << "--profile"      if @submitted_options[:profile_examples]
    argv << "--backtrace"    if @submitted_options[:full_backtrace]
    argv << "--tty"          if @submitted_options[:tty]
    argv << "--fail-fast"    if @submitted_options[:fail_fast]
    argv << "--options"      << @submitted_options[:custom_options_file] if @submitted_options[:custom_options_file]
    argv << "--order"        << @submitted_options[:orderby]             if @submitted_options[:orderby]

    add_full_description(argv)
    add_line_numbers(argv)
    add_filter(argv, :inclusion)
    add_filter(argv, :exclusion)
    add_formatters(argv)
    add_libs(argv)
    add_requires(argv)

    argv + @submitted_options[:files_or_directories_to_run]
  end

  def add_full_description(argv)
    if @submitted_options[:full_description]
      # The argument to --example is regexp-escaped before being stuffed
      # into a regexp when received for the first time (see OptionParser).
      # Hence, merely grabbing the source of this regexp will retain the
      # backslashes, so we must remove them.
      argv << "--example" << @submitted_options[:full_description].source.delete('\\')
    end
  end

  def add_line_numbers(argv)
    if @submitted_options[:line_numbers]
      argv.push(*@submitted_options[:line_numbers].inject([]){|a,l| a << "--line_number" << l})
    end
  end

  def add_filter(argv, name)
    @submitted_options["#{name}_filter".to_sym].each_pair do |k, v|
      tag = name == :inclusion ? k.to_s : "~#{k.to_s}"
      tag << ":#{v.to_s}" if v.is_a?(String)
      argv << "--tag" << tag
    end if @submitted_options["#{name}_filter".to_sym]
  end

  def add_formatters(argv)
    @submitted_options[:formatters].each do |pair|
      argv << "--format" << pair[0]
      argv << "--out" << pair[1] if pair[1]
    end if @submitted_options[:formatters]
  end

  def add_libs(argv)
    @submitted_options[:libs].each do |path|
      argv << "-I" << path
    end if @submitted_options[:libs]
  end

  def add_requires(argv)
    @submitted_options[:requires].each do |path|
      argv << "--require" << path
    end if @submitted_options[:requires]
  end
end
