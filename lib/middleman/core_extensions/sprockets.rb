require 'pathname'
require 'rbconfig'
require "sprockets"

module Middleman::CoreExtensions::Sprockets
  class << self
    def registered(app)
      app.set :js_compressor, false
      app.set :css_compressor, false
      
      # Cut off every extension after .js (which sprockets eats up)
      app.build_reroute do |destination, request_path|
        if !request_path.match(/\.js\./i)
          false
        else
          [
            destination.gsub(/\.js(\..*)$/, ".js"),
            request_path.gsub(/\.js(\..*)$/, ".js")
          ]
        end
      end
      
      app.after_configuration do
        js_env = Middleman::CoreExtensions::Sprockets::JavascriptEnvironment.new(app)
        
        vendor_dir = File.join("vendor", "assets", "javascripts")
        gems_with_js = ::Middleman.rubygems_latest_specs.select do |spec|
          ::Middleman.spec_has_file?(spec, vendor_dir)
        end.each do |spec|
          js_env.append_path File.join(spec.full_gem_path, vendor_dir)
        end
        
        app_dir = File.join("app", "assets", "javascripts")
        gems_with_js = ::Middleman.rubygems_latest_specs.select do |spec|
          ::Middleman.spec_has_file?(spec, app_dir)
        end.each do |spec|
          js_env.append_path File.join(spec.full_gem_path, app_dir)
        end
        
        # add paths to js_env (vendor/assets/javascripts)
        app.map "/#{app.js_dir}" do
          run js_env
        end
      end
        
      app.after_compass_config do
        css_env = Middleman::CoreExtensions::Sprockets::StylesheetEnvironment.new(app)
        
        vendor_dir = File.join("vendor", "assets", "stylesheets")
        gems_with_css = ::Middleman.rubygems_latest_specs.select do |spec|
          ::Middleman.spec_has_file?(spec, vendor_dir)
        end.each do |spec|
          css_env.append_path File.join(spec.full_gem_path, vendor_dir)
        end

        app_dir = File.join("app", "assets", "stylesheets")
        gems_with_css = ::Middleman.rubygems_latest_specs.select do |spec|
          ::Middleman.spec_has_file?(spec, app_dir)
        end.each do |spec|
          css_env.append_path File.join(spec.full_gem_path, app_dir)
        end
        
        app.map "/#{app.css_dir}" do
          run css_env
        end
      end
    end
    alias :included :registered
  end

  class MiddlemanEnvironment < ::Sprockets::Environment
    def initialize(app)
      full_path = app.views
      full_path = File.join(app.root, app.views) unless app.views.include?(app.root)
      
      super File.expand_path(full_path)
      
      # Make the app context available to Sprockets
      context_class.send(:define_method, :app) { app }
      context_class.class_eval do
        def method_missing(name)
          if app.respond_to?(name)
            app.send(name)
          else
            super
          end
        end
      end
    end
  end
    
  class JavascriptEnvironment < MiddlemanEnvironment
    def initialize(app)
      super

      # Disable css
      # unregister_processor "text/css", ::Sprockets::DirectiveProcessor
      
      self.js_compressor = app.settings.js_compressor

      # configure search paths
      append_path app.js_dir
    end
    
    def javascript_exception_response(exception)
      expire_index!
      super(exception)
    end
  end
  
  class StylesheetEnvironment < MiddlemanEnvironment
    def initialize(app)
      super
  
      # Disable js
      # unregister_processor "application/javascript", ::Sprockets::DirectiveProcessor
      
      self.css_compressor = app.settings.css_compressor
  
      # configure search paths
      append_path app.css_dir
    end
  
    def css_exception_response(exception)
      expire_index!
      super(exception)
    end
  end
end