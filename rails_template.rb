#----------------------------------------------------------------------------
# Setup Application
#----------------------------------------------------------------------------

# Description
puts "Modifying a new Rails app to use sensible defaults..."

# Git
puts "Setting up a blank git repository..."
git :init


#----------------------------------------------------------------------------
# Clean up files
#----------------------------------------------------------------------------

# Remove unnecessary files
puts "Remove unnecessary files."
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"
run "rm app/assets/images/rails.png"
run "rm -r test/"

# Recreate the README file
puts "Clear out README file contents and switching to Markdown. Generate TODO file."
run "rm README"
run "echo 'TODO' > README.md"
run "echo 'TODO' > TODO.md"

# Move database.yml
puts "Backup database.yml since we're not including it in the git repository."
run "cp config/database.yml config/database.yml.example"

# Add to .gitignore
puts "Extend .gitignore to keep our repository clean and safe."
append_file ".gitignore" do
<<-END
config/database.yml
*.swp
*~
.DS_Store
coverage/
private/system/
public/system/
END
end


#----------------------------------------------------------------------------
# Configuration
#----------------------------------------------------------------------------

# Don't log password_confirmation fields
puts "Don't log password_confirmation fields."
gsub_file "config/application.rb", /:password/, ":password, :password_confirmation"

# Don't generate default stylesheets/javascripts when scaffolding
puts "Don't generate default stylesheets or javascripts when scaffolding."
inject_into_file "config/application.rb", :before => "    # Enable the asset pipeline" do
<<-END
    # Setup generators
    config.generators do |g|
      g.scaffold :stylesheets => false
      g.scaffold :javascripts => false
    end

END
end

# Get the closest timezone using the system clock
puts "Try to get the local time zone."
timezone = %x{rake time:zones:local}.split("\n").delete_if {|x| x.blank? || x[0] == '*'}[0]
inject_into_file "config/application.rb", :after => "# config.time_zone = 'Central Time (US & Canada)'\n" do
  "    config.time_zone = '#{timezone}'\n"
end

# Setup mailer options
puts "Setup mailer options."
inject_into_file 'config/environments/development.rb', :after => "config.assets.compress = false\n" do
<<-END

  # Mail
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
END
end

inject_into_file 'config/environments/production.rb', :after => "config.active_support.deprecation = :notify\n" do
<<-END

  # Mail
  config.action_mailer.default_url_options = { :host => 'www.example.com' }
END
end

inject_into_file 'config/environments/test.rb', :after => "config.active_support.deprecation = :stderr\n" do
<<-END

  # Mail
  config.action_mailer.default_url_options = { :host => 'www.example.com' }
END
end

## Use database for sessions
#puts "Switch to ActiveRecord session store."
#gsub_file 'config/initializers/session_store.rb', "#{app_name}::Application.config.session_store :cookie_store",   "# #{app_name}::Application.config.session_store :cookie_store"
#gsub_file "config/initializers/session_store.rb", "# #{app_name}::Application.config.session_store :active_record_store", "#{app_name}::Application.config.session_store :active_record_store"
#generate "session_migration"


#----------------------------------------------------------------------------
# Gems
#----------------------------------------------------------------------------

puts "Add to the Gemfile."
gsub_file 'Gemfile', /^#.*\n/, ''
inject_into_file 'Gemfile', :before => "group :test do\n" do
<<-END
gem 'modernizr-rails'
gem 'responders'
gem 'simple_form'
gem 'high_voltage'
gem 'redcarpet'

# Need a JavaScript runtime?
# gem 'therubyracer'

END
end

# Testing gems
inject_into_file 'Gemfile', :after => "group :test do\n" do
<<-END
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'database_cleaner'
  gem 'simplecov', :require => false
  # gem 'timecop'
  # gem 'fakeweb'

END
end

# Development/Test and Development gems
append_to_file 'Gemfile' do
<<-END

group :development, :test do
  gem 'rspec-rails'
  gem 'launchy'
end

group :development do
  gem 'capistrano'
  gem 'rails-footnotes'
  gem 'letter_opener'
end
END
end

# Install gems
puts "Installing gems with bundler. Go and get some coffee, this could take a while..."
run "bundle install"

# Generators
puts "Installing gems/running generators."

puts "Install 'Responders' gem."
generate "responders:install"

puts "Install 'Simple Form' gem."
generate "simple_form:install"

puts "Install RSpec gem."
generate "rspec:install"

puts "Install Factory Girl gem."
run "touch spec/factories.rb"
gsub_file "spec/spec_helper.rb", "config.fixture_path", "# config.fixture_path"

puts "Install 'Capybara' gem."
inject_into_file 'spec/spec_helper.rb', :after => "require 'rspec/rails'\n" do
  "require 'capybara/rspec'\n"
end

puts "Install 'Database Cleaner' gem."
gsub_file "spec/spec_helper.rb", "config.use_transactional_fixtures = true",
<<-END

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
END

puts "Install 'SimpleCov' gem."
prepend_to_file 'spec/spec_helper.rb', "require 'simplecov'\nSimpleCov.start 'rails'\n\n"

puts "Install 'High Voltage' gem, and generate a static Home Page."
run "mkdir app/views/pages"
file "app/views/pages/home.html.erb" do
  "<h1>RailsApp</h1>\n<p>Welcome to your new Rails application.</p>"
end

file "spec/requests/static_pages_spec.rb" do
<<-END
require 'spec_helper'

describe "Home Page" do
  describe "GET /" do
    it "displays the home page" do
      visit root_path
      page.should have_content("Welcome to your new Rails application")
    end
  end
end
END
end

inject_into_file 'config/routes.rb', :after => "routes.draw do" do
  "\n  root :to => 'high_voltage/pages#show', :id => 'home'\n"
end
gsub_file 'config/routes.rb', /  #.*end/m, 'end'


#----------------------------------------------------------------------------
# Application Configuration YAML file
#----------------------------------------------------------------------------
puts "Generate a YAML Application Configuration file."
file "config/initializers/app_config.rb" do
<<-END
# Application Configuration
APP_CONFIG = YAML.load_file("#{ '#{Rails.root}' }/config/app_config.yml")[Rails.env].symbolize_keys
END
end

file "config/app_config.yml" do
<<-END
# Application Configuration
defaults: &defaults
  site_title: 'Rails App'
  # page_limit: 25

development: &development
  <<: *defaults

test:
  <<: *development

production:
  <<: *defaults
  # google_analytics_ua: 'UA-XXXXX-X'
END
end


#----------------------------------------------------------------------------
# Application Helpers
#----------------------------------------------------------------------------
puts "Create some basic application helpers."
run "mkdir spec/helpers"
file "spec/helpers/application_helper_spec.rb" do
<<-END
require 'spec_helper'

describe ApplicationHelper do

  # Render flash messages in layout
  it "should format and display all Flash messages in the layout" do
    flash_messages.should be_nil

    flash[:notice] = "Hello world."
    flash_messages.should == %Q{<div id="flash-messages"><div class="flash-notice">Hello world.<a href="#" class="close" title="close">X</a></div></div>}

    flash[:warning] = "Hey...be careful!"
    flash_messages.should == %Q{<div id="flash-messages"><div class="flash-notice">Hello world.<a href="#" class="close" title="close">X</a></div><div class="flash-warning">Hey...be careful!<a href="#" class="close" title="close">X</a></div></div>}
  end

  # Return the title on a per-page basis
  it "should return Site Title based on App Config" do
    APP_CONFIG[:site_title] = "MySite"
    title.should == "MySite"

    @title = "MyPage"
    title.should == "MyPage | MySite"
  end

  # Render input using Markdown
  it "should render input to HTML using Liquid and Markdown" do
    input = "This is some _Markdown_ content.\n\nHere's **another** paragraph."
    markup(input).should == "<p>This is some <em>Markdown</em> content.</p>\n\n<p>Here&rsquo;s <strong>another</strong> paragraph.</p>\n"
    markup(nil).should == ""
  end

  # Format Datetime into HTML5 <time> compliant format
  it "should convert DateTime into HTML5 <time> compliant format" do
    time = Time.new(2011,04,27,10,30,0,"+00:00")
    format_datetime(time).should == "2011-04-27"
  end

  # Format Time into a user friendly string
  it "should convert Time into user friendly string" do
    time = Time.new(2011,04,27,10,30,0,"+00:00")

    pretty_time(time).should == "April 27, 2011"
    pretty_time(time, :short).should == "27/04/2011"
    pretty_time(time, :medium).should == "April 27, 2011"
    pretty_time(time, :long).should == "April 27, 2011 10:30am"
  end

  # Convert Boolean values into colour-coded strings for HTML output
  it "should display Boolean values as colour coded, HTML formatted string" do
    pretty_boolean(true).should =~ /yes/i
    pretty_boolean(false).should =~ /no/i
  end

end
END
end

inject_into_file "app/helpers/application_helper.rb", :after => "module ApplicationHelper" do
<<-END


  # Render flash messages in layout
  def flash_messages
    unless flash.blank?
      msg = '<div id="flash-messages">'
      flash.each do |key, message|
        msg << %Q{<div class="flash-#{ '#{key}' }">#{ '#{message}' }<a href="#" class="close" title="close">X</a></div>}
      end
      "#{ '#{msg}' }</div>".html_safe
    end
  end

  # Return the title on a per-page basis
  def title
    base_title = APP_CONFIG[:site_title]
    if @title.nil?
      base_title
    else
      "#{ '#{@title}' } | #{ '#{base_title}' }"
    end
  end

  # Render input as Markdown
  def markup(text = nil)
    text ||= ''
    options = [:hard_wrap, :autolink, :smart, :no_intraemphasis, :fenced_code, :gh_blockcode]
    Redcarpet.new(text, *options).to_html.html_safe
  end

  # Format Datetime into HTML5 format
  def format_datetime(datetime)
    datetime.strftime('%Y-%m-%d')
  end

  # Format Datetime into a user friendly string
  def pretty_time(time, format = :medium)
    case format
      when :short
        strf = "%d/%m/%Y"
      when :long
        strf = "%B %d, %Y %l:%M%P"
      else
        strf = "%B %d, %Y"
    end
    time.strftime(strf)
  end

  # Convert Boolean values into colour-coded strings for HTML output
  def pretty_boolean(val)
    output = val ? '<span style="color:#050">Yes</span>' : '<span style="color:#c00">No</span>'
    output.html_safe
  end
END
end


#----------------------------------------------------------------------------
# H5BP
#----------------------------------------------------------------------------

# CSS
puts "Get H5BP Stylesheets."
run "rm app/assets/stylesheets/application.css"
get "https://github.com/paulirish/html5-boilerplate/raw/master/css/style.css", "app/assets/stylesheets/application.css.scss.erb"

# JavaScript
puts "Get H5BP JavaScripts."
get "https://github.com/paulirish/html5-boilerplate/raw/master/js/script.js", "app/assets/javascripts/script.js"
get "https://github.com/paulirish/html5-boilerplate/raw/master/js/plugins.js", "app/assets/javascripts/plugins.js"
gsub_file 'app/assets/javascripts/application.js', "//= require_tree ." do
<<-END
//= require plugins
//= require script
END
end
inject_into_file 'app/assets/javascripts/application.js', :before => "//= require jquery\n" do
  "//= require modernizr\n"
end

# IE
puts "Get JavaScripts to help IE."
run "mkdir app/assets/javascripts/ie"
file "app/assets/javascripts/ie/ie.js" do
<<-END
// FIXME: Tell people that this is a manifest file, real code should go into discrete files
// FIXME: Tell people how Sprockets and CoffeeScript works
//
//= require ie/DOMAssistant
//= require ie/selectivizr
END
end
get "http://domassistant.googlecode.com/files/DOMAssistantComplete-2.8.js", "app/assets/javascripts/ie/DOMAssistant.js"
get "https://github.com/keithclark/selectivizr/raw/master/selectivizr.js", "app/assets/javascripts/ie/selectivizr.js"

# index.html
puts "Get H5BP application layout."
run "rm app/views/layouts/application.html.erb"
get "https://github.com/paulirish/html5-boilerplate/raw/master/index.html", "app/views/layouts/application.html.erb"

gsub_file "app/views/layouts/application.html.erb", '<title></title>', '<title><%= title -%></title>'

gsub_file 'app/views/layouts/application.html.erb', /<link rel="stylesheet".*<\/head>/mi do
<<-END
<%= stylesheet_link_tag "application" %>
  <%= javascript_include_tag "application" %>
  <!--[if lt IE 9]><%= javascript_include_tag 'ie/ie' %><![endif]-->
  <%= csrf_meta_tag %>
</head>
END
end

gsub_file 'app/views/layouts/application.html.erb', '<header>', '<header role="banner" class="clearfix">'
gsub_file 'app/views/layouts/application.html.erb', '<footer>', '<footer role="contentinfo" class="clearfix">'
gsub_file 'app/views/layouts/application.html.erb', '<div role="main">', '<div id="main" role="main" class="clearfix">'
gsub_file 'app/views/layouts/application.html.erb', "\n  </header>", "    <h1><%= link_to APP_CONFIG[:site_title], root_path -%></h1>\n  </header>"
inject_into_file 'app/views/layouts/application.html.erb', :after => "<div id=\"main\" role=\"main\" class=\"clearfix\">\n" do
  %Q(    <%= raw flash_messages %>\n    <%= yield %>)
end
gsub_file 'app/views/layouts/application.html.erb',  /<!-- JavaScript at the bottom for fast page loading -->.*<!-- end scripts -->/mi, ''

gsub_file 'app/views/layouts/application.html.erb', "<script>\n    var _gaq=[[", "<% if APP_CONFIG[:google_analytics_ua] -%>\n  <script>\n    var _gaq=[["
inject_into_file 'app/views/layouts/application.html.erb', :after => /google_analytics_ua.*^\s{2}<\/script>/m, do
  "\n  <% end -%>"
end
gsub_file 'app/views/layouts/application.html.erb', 'UA-XXXXX-X', "<%= APP_CONFIG[:google_analytics_ua] -%>"

# Public Files
puts "Get H5BP Public files."
get "https://github.com/paulirish/html5-boilerplate/raw/master/crossdomain.xml", "public/crossdomain.xml"
get "https://github.com/paulirish/html5-boilerplate/raw/master/humans.txt", "public/humans.txt"
get "https://github.com/paulirish/html5-boilerplate/raw/master/robots.txt", "public/robots.txt"
get "https://github.com/paulirish/html5-boilerplate/raw/master/favicon.ico", "public/favicon.ico"
get "https://github.com/paulirish/html5-boilerplate/raw/master/apple-touch-icon.png", "public/apple-touch-icon.png"
get "https://github.com/paulirish/html5-boilerplate/raw/master/apple-touch-icon-precomposed.png", "public/apple-touch-icon-precomposed.png"
get "https://github.com/paulirish/html5-boilerplate/raw/master/apple-touch-icon-72x72-precomposed.png", "public/apple-touch-icon-72x72-precomposed.png"
get "https://github.com/paulirish/html5-boilerplate/raw/master/apple-touch-icon-57x57-precomposed.png", "public/apple-touch-icon-57x57-precomposed.png"
get "https://github.com/paulirish/html5-boilerplate/raw/master/apple-touch-icon-114x114-precomposed.png", "public/apple-touch-icon-114x114-precomposed.png"


#----------------------------------------------------------------------------
# Finish up
#----------------------------------------------------------------------------

# Git
puts "Adding all files to git repository and making the 'initial commit'."
git :add => "."
git :commit => "-m 'Initial commit'"

# Migrate database
run "bundle exec rake db:migrate"

# Done!
puts "Done setting up your new Rails app. Have fun!"
