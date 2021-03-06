module Seedbank
  module DSL
    refine Object do
    def override_seed_task(*args)
      task_name, arg_names, deps = Rake.application.resolve_args(args)
      seed_task = Rake::Task.task_defined?(task_name) ? Rake::Task[task_name].clear : Rake::Task.define_task(task_name)
      add_comment_to(seed_task, Rake.application.last_description)
      add_environment_dependency(seed_task)
      seed_task.enhance deps
    end

    def seed_task_from_file(seed_file)
      scopes  = scope_from_seed_file(seed_file)
      fq_name = scopes.push(File.basename(seed_file, '.seeds.rb')).join(':')

      define_seed_task(seed_file, fq_name)
    end

    def glob_seed_files_matching(*args, &block)
      Dir.glob(File.join(seeds_root, *args), &block)
    end

    def runner
      @_seedbank_runner ||= Seedbank::Runner.new
    end

    def define_seed_task(seed_file, *args)
      task = Rake::Task.define_task(*args) do |seed_task|
        runner.evaluate(seed_task, seed_file) if File.exist?(seed_file)
      end

      task.add_description "Load the seed data from #{seed_file}"
      add_environment_dependency(task)
      task.name
    end

    def add_environment_dependency(task)
      if Rake::Task.task_defined?('db:abort_if_pending_migrations')
        task.enhance(['db:abort_if_pending_migrations'])
      elsif Rake::Task.task_defined?(':environment')
        task.enhance([':environment'])
      end
    end

    def scope_from_seed_file(seed_file)
      dirname = Pathname.new(seed_file).dirname
      return [] if dirname == seeds_root
      relative = dirname.relative_path_from(seeds_root)
      relative.to_s.split(File::Separator)
    end

    def seeds_root
      Pathname.new Seedbank.seeds_root
    end

    private

    def add_comment_to(seed_task, comment)
      if seed_task.respond_to?(:clear_comments)
        seed_task.comment = comment
      else
        seed_task.send :instance_variable_set, '@full_comment', comment
      end
    end
  end
end
end
