require 'rspec/expectations'

module Capistrano
  module Spec
    module ConfigurationExtension
      def get(remote_path, path, options={}, &block)
        gets[remote_path] = {:path => path, :options => options, :block => block}
      end

      def gets
        @gets ||= {}
      end

      def run(cmd, options={}, &block)
        runs[cmd] = {:options => options, :block => block}
      end

      def runs
        @runs ||= {}
      end

      def upload(from, to, options={}, &block)
        uploads[from] = {:to => to, :options => options, :block => block}
      end

      def uploads
        @uploads ||= {}
      end
      
    end

    # See also: https://github.com/capistrano/capistrano/blob/master/lib/capistrano/task_definition.rb
    # TODO: handle case where find_callback() searches for a task without specifying its namespace.
    class DummyTask
      def new fully_qualified_name
        @name = fully_qualified_name
      end
      def fully_qualified_name
        @name
      end
    end

    module Helpers
      # TODO: consider renaming this to find_callbacks() as it can return multiple callbacks.
      def find_callback(configuration, on, task)
        original_task = task.dup
        if task.kind_of?(String)
          # This works if the task you are looking for was defined in the configuration you are testing.
          # This will NOT work if you try: find_callback @conf, :after, "deploy:setup"
          #   and the code you are testing has specified: after "deploy:setup", "deploy:extras"
          #   and "deploy:extras" is a task you have defined in your code but "deploy:setup" is simply
          #   the task which is already defined by https://github.com/capistrano/capistrano/blob/master/lib/capistrano/recipes/deploy.rb
          task = configuration.find_task(task)
          # Workaround is to create a dummy task for the edge cases mentioned above.
          task = DummyTask.new original_task if task.nil?
        end

        return nil if task.nil? # otherwise applies_to?() below always returns true, producing false positives.

        callbacks = configuration.callbacks[on]

        callbacks && callbacks.select do |task_callback|
          # https://github.com/capistrano/capistrano/blob/master/lib/capistrano/callback.rb
          task_callback.applies_to?(task) || task_callback.source == task.fully_qualified_name
        end
      end

    end

    module Matchers
      extend ::RSpec::Matchers::DSL
    
      define :callback do |task_name|
        extend Helpers
    
        match do |configuration|
          @task = configuration.find_task(task_name)
          callbacks = find_callback(configuration, @on, @task)
    
          if callbacks
            @callback = callbacks.first
    
            if @callback && @after_task_name
              @after_task = configuration.find_task(@after_task_name)
              @callback.applies_to?(@after_task)
            elsif @callback && @before_task_name
              @before_task = configuration.find_task(@before_task_name)
              @callback.applies_to?(@before_task)
            else
              ! @callback.nil?
            end
          else
            false
          end
        end
    
        def on(on)
          @on = on
          self
        end
    
        def before(before_task_name)
          @on = :before
          @before_task_name = before_task_name
          self
        end
    
        def after(after_task_name)
          @on = :after
          @after_task_name = after_task_name
          self
        end
    
        failure_message_for_should do |actual|
          if @after_task_name
            "expected configuration to callback #{task_name.inspect} #{@on} #{@after_task_name.inspect}, but did not"
          elsif @before_task_name
            "expected configuration to callback #{task_name.inspect} #{@on} #{@before_task_name.inspect}, but did not"
          else
            "expected configuration to callback #{task_name.inspect} on #{@on}, but did not"
          end
        end
    
      end
    
      define :have_gotten do |path|
        match do |configuration|
    
          get = configuration.gets[path]
          if @to
            get && get[:path] == @to
          else
            get
          end
        end
    
        def to(to)
          @to = to
          self
        end
    
        failure_message_for_should do |actual|
          if @to
            "expected configuration to get #{path} to #{@to}, but did not"
          else
            "expected configuration to get #{path}, but did not"
          end
        end
      end
    
      define :have_uploaded do |path|
        match do |configuration|
          upload = configuration.uploads[path]
          if @to
            upload && upload[:to] == @to
          else
            upload
          end
        end
    
        def to(to)
          @to = to
          self
        end
    
        failure_message_for_should do |actual|
          if @to
            "expected configuration to upload #{path} to #{@to}, but did not"
          else
            "expected configuration to upload #{path}, but did not"
          end
        end
      end
    
      define :have_run do |cmd|
    
        match do |configuration|
          run = configuration.runs[cmd]
    
          run
        end
    
       failure_message_for_should do |actual|
         "expected configuration to run #{cmd}, but did not"
       end
        
     end
    
    end
  end
end

