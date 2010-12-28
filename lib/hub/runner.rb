module Hub
  # The Hub runner expects to be initialized with `ARGV` and primarily
  # exists to run a git command.
  #
  # The actual functionality, that is, the code it runs when it needs to
  # augment a git command, is kept in the `Hub::Commands` module.
  class Runner
    attr_reader :args
    
    def initialize(*args)
      @args = Args.new(args)

      # Hack to emulate git-style
      @args.unshift 'help' if @args.grep(/^[^-]|version|exec-path$|html-path/).empty?

      # git commands can have dashes
      cmd = @args[0].sub(/(\w)-/, '\1_')
      Commands.send(cmd, @args) if Commands.method_defined?(cmd)
    end

    # Shortcut
    def self.execute(*args)
      new(*args).execute
    end

    # A string representation of the command that would run.
    def command
      if args.skip?
        ''
      else
        commands.join('; ')
      end
    end

    # An array of all commands as strings.
    def commands
      args.commands.map do |cmd|
        if cmd.respond_to?(:join)
          cmd.map { |c| c.index(' ') ? "'#{c}'" : c }.join(' ')
        else
          cmd.to_s
        end
      end
    end

    # Runs the target git command with an optional callback. Replaces
    # the current process. 
    # 
    # If `args` is empty, this will skip calling the git command. This
    # allows commands to print an error message and cancel their own
    # execution if they don't make sense.
    def execute
      unless args.skip?
        if args.chained?
          execute_command_chain
        else
          exec(*args.to_exec)
        end
      end
    end

    # Runs multiple commands in succession; exits at first failure.
    def execute_command_chain
      commands = args.commands
      commands.each_with_index do |cmd, i|
        if cmd.respond_to?(:call) then cmd.call
        elsif i == commands.length - 1
          # last command in chain
          exec(*cmd)
        else
          exit($?.exitstatus) unless system(*cmd)
        end
      end
    end
  end
end
