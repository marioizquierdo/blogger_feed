namespace :blogger_feed do
  
  desc "Update all local BloggerFeed data from corresponding sources. (use force_reload=true to replace all entries again)"
  task :refresh_all => :environment do
    force_reload = ENV['FORCE_RELOAD'] || ENV['force_reload']
    BloggerFeed.all.each do |feed|
      update_from_source(feed, :force_reload => force_reload)
      puts ''
    end
  end
   
  desc "Update local data for the specified BLOG_NAME. Example: rake teixo:blogger_feed:refresh BLOG_NAME=gestoresderesiduos. (use force_reload=true to replace all entries again)"
  task :refresh => :environment do
    feed = BloggerFeed[ENV['BLOG_NAME'] || ENV['blog_name']]
    force_reload = ENV['FORCE_RELOAD'] || ENV['force_reload']
    if feed
      update_from_source(feed, :force_reload => force_reload)
    else
      puts " x> Error: BloggerFeed not found. Please use a valid BLOG_NAME (check blogger_feed database table if needed)."
      puts " x> Usage example: rake blogger_feed:refresh BLOG_NAME=teixo"
      puts " x> If you want to reload all feeds use: rake teixo:blogger_feed:refresh_all"
    end
  end
  
  desc "Change ClientLogin email and password params to authenticate in a private blog. " + 
        "Args: BLOG_NAME, EMAIL (optional), PASSWORD  (optional), PUBLIC_ACCESS (optional) = true if you want to delete previous email and password." +
        "Example: rake blogger_feed:update_client_login_access BLOG_NAME=gestoresderesiduos PASSWORD=MyNewPass69"
  task :update_client_login_access => :environment do
    feed = BloggerFeed[ENV['BLOG_NAME'] || ENV['blog_name']]
    email = ENV['EMAIL'] || ENV['email']
    password = ENV['PASSWORD'] || ENV['password'] || ENV['PASSWD'] || ENV['passwd'] || ENV['PASS'] || ENV['pass']
    public_access = ENV['PUBLIC_ACCESS'] || ENV['public_access']
    
    if feed
      if public_access
        feed.client_login_email = nil
        feed.client_login_password = nil
        feed.save!
        puts " > Make it Public. Previous Email and Password Deleted"
      else
        if email
          prev_email = feed.client_login_email
          feed.client_login_email = email
          puts " > Change email from #{prev_email.inspect} to #{email.inspect}"
        end
        if password
          prev_password = feed.client_login_password
          feed.client_login_password = password
          puts " > Change password from #{prev_password.inspect} to #{password.inspect}"
        end
        feed.save!
        puts " > Make it Private."
      end
    else
      puts " x> Error: BloggerFeed not found. Please use a valid BLOG_NAME (check blogger_feed database table if needed)."
      puts " x> Usage example: rake blogger_feed:update_client_login_access BLOG_NAME=teixo EMAIL=new@email PASSWORD=newPass"
    end
  end
  
  desc "Change the attribute link_to_public_feed_address in the specified BloggerFeed. If you have a service like FeedBurner, is better to attach its url to the model than manage it in the views. " +
        "Args: BLOG_NAME, VALUE. Example: rake blogger_feed:set_link_to_public_feed_address BLOG_NAME=teimas_es VALUE=http://feeds.feedburner.com/teimas_es"
  task :set_link_to_public_feed_address => :environment do
    feed = BloggerFeed[ENV['BLOG_NAME'] || ENV['blog_name']]
    value = ENV['VALUE'] || ENV['value']
    
    if feed
      if value
        prev = feed.link_to_public_feed_address
        feed.link_to_public_feed_address = value
        feed.client_login_password = nil
        puts " > Change link_to_public_feed_address from #{prev.inspect} to #{value.inspect}"
        feed.save!
      else
        puts " x> Error: Arg VALUE not found. Usage example: rake blogger_feed:set_link_to_public_feed_address BLOG_NAME=teixo VALUE=http://feeds.feedburner.com/teixo"
      end
    else
      puts " x> Error: BloggerFeed not found. Please use a valid BLOG_NAME (check blogger_feed database table if needed)."
      puts " x> Usage example: rake blogger_feed:set_link_to_public_feed_address BLOG_NAME=my_blog VALUE=http://feeds.feedburner.com/feed_of_my_blog"
    end
  end
  
  # Invoca al método feed.update_from_source y muestra los resultados por pantalla.
  def update_from_source(feed, options = {})
    begin
      puts " > Blog #{feed.blog_name}:"
      updated_data = feed.update_from_source options
      puts "#{updated_data.to_yaml}"
    rescue ActiveRecord::RecordInvalid => invalid
      puts " x> Try to save a #{invalid.record.class.class_name} but has #{invalid.record.errors.count} errors: #{invalid.record.errors.full_messages.join('. And ')}"
    rescue => error
      puts " x> #{error.class}: #{error.message}"
      print error.backtrace.join("\n")
    end
  end
  
end



