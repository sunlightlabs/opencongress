class FixCaptchaBrowserStateIdTable < ActiveRecord::Migration
  def self.up
    remove_column :formageddon_threads, :captcha_browser_state_id
    add_column :formageddon_delivery_attempts, :captcha_browser_state_id, :text
  end

  def self.down
    add_column :formageddon_threads, :captcha_browser_state_id, :text
    remove_column :formageddon_delivery_attempts, :captcha_browser_state_id
  end
end
