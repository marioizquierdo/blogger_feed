#
# This is a sample migration to create new blogger_feeds in the database.
#
class CreateBloggerFeeds < ActiveRecord::Migration
  def self.up
    
    say "Add to blogger_feeds from Blogger RSS source:"
    imported_data = BloggerFeed.create_from_source 'teimas_es', '316349184984424932'  # http://www.blogger.com/feeds/316349184984424932/posts/default
    say "teimas_es: #{imported_data.inspect}", true
    imported_data = BloggerFeed.create_from_source 'teimas_gl', '1230444769005184054' # http://www.blogger.com/feeds/1230444769005184054/posts/default
    say "teimas_gl: #{imported_data.inspect}", true
    
  end

  def self.down
    BloggerFeed['gestoresderesiduos'].destroy
    BloggerFeed['teixo'].destroy
  end
end
