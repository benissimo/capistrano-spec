require 'capistrano'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module Capistrano
  module Example
    def self.load_defaults_into(configuration)
      # TODO: add some defaults here and then specs verifying they can be asserted against.
    end
    def self.load_callbacks_into(configuration)
      configuration.load do
        before "bundle:install", "deploy:profile"
        after "deploy:setup", "deploy:extras"
        after "deploy:update", "newrelic:notice_deployment"
        after "deploy:update", "deploy:custom_symlinks"
      end
    end
    def self.load_into(configuration)
      load_defaults_into(configuration)
      load_callbacks_into(configuration)
      configuration.load do
        namespace :deploy do
          task :extra, :roles => :web, :except => { :no_release => true } do
            run "echo 'extra'" # dummy task
          end
        end
      end
    end
  end
end

describe "CapistranoSpec" do
  before do
    @configuration = Capistrano::Configuration.new
    @configuration.extend(Capistrano::Spec::ConfigurationExtension)
    Capistrano::Example.load_into(@configuration)
  end
  # Note that these specs fail with the original code I forked this branch from.
  describe "find_callback helper" do
    it "should call deploy:extras after deploy:setup" do
      callbacks = find_callback(@configuration, :after, 'deploy:setup')
      callbacks.should_not be_empty
      callbacks.map(&:source).should == ['deploy:extras']
    end
    it "should call newrelic:notice_deployment and deploy:custom_symlinks after deploy:update" do
      callbacks = find_callback(@configuration, :after, 'deploy:update')
      callbacks.should_not be_empty
      callbacks.map(&:source).should == ['newrelic:notice_deployment','deploy:custom_symlinks']
    end
    it "should call bundle:install before deploy:profile" do
      callbacks = find_callback(@configuration, :before, 'bundle:install')
      callbacks.should_not be_empty
      callbacks.map(&:source).should == ['deploy:profile']
    end
  end
  # TODO: add specs for have_gotten (rename?), have_uploaded.
  # TODO: figure out how to use callback matcher and add a spec for that too.
  describe "have_run matcher" do
    it "works" do
      @configuration.find_and_execute_task('deploy:extra')
      @configuration.should have_run("echo 'extra'")
      @configuration.should_not have_run("something else")
    end
  end
end
