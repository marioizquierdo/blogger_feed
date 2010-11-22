#
# To apply this migration, copy this file to the db/migrate folder and change its name with the 
# current timestamp (or use script/generate migration CreateControllerActionsLogs and copy-paste this content).
# Then simply run rake db:migrate
#
class CreateBloggerFeeds < ActiveRecord::Migration
  def self.up
    create_table :blogger_feeds do |t|
      t.string   "blog_name"
      t.string   "blog_id"
      t.string   "feed_id"
      t.string   "link_self_href"
      t.string   "link_alternate_href"
      t.string   "title"
      t.string   "etag"
      t.string   "client_login_email"
      t.string   "client_login_password"
      t.string   "link_to_public_feed_address"
      t.datetime "updated_from_source_timestamp"
    end
    
    create_table :blogger_feed_entries do |t|
      t.integer  "blogger_feed_id"
      t.string   "entry_id"
      t.string   "title"
      t.string   "link_self_href"
      t.string   "link_alternate_href"
      t.string   "link_atom_xml_href"
      t.string   "etag"
      t.text     "content"
      t.text     "summary"
      t.datetime "published"
      t.datetime "updated"
      t.string   "clean_url_id",        :limit => 250
    end
    add_index :blogger_feed_entries, :clean_url_id
  end

  def self.down
    remove_index :blogger_feed_entries, :clean_url_id
    drop_table :blogger_feed_entries
    drop_table :blogger_feeds
  end
end
