module Spammable
  # Handles spam checking / censoring for a comment-like model
  # Your model must(*)/should include or map the following:
  #
  # :author*, :author_url, :author_email*, :content*,
  # :user_ip*, :user_agent, :referrer
  #
  # non-matching names can be mapped via a `rakismet_attrs` macro:
  # rakismet_attrs({
  #   :author => proc {|c| c.user.full_name },
  #   :author_email => proc {|c| c.user.email }
  # })
  #
  # additionally, your model needs to implement 2 fields, `spam` and `censored`
  # both exist so that technically innocent, but trolling, comments can be muted
  # without marking the commenter's IP or name as spam.

  extend ActiveSupport::Concern

  included do
    include Rakismet::Model
    before_save :check_for_spam, :unless => :persisted?
    alias_method :is_spam?, :spam?
    scope :spam, where("spam=TRUE")
    scope :ham, where("(spam is NULL or spam=FALSE) AND (censored is NULL or censored=FALSE)")
    scope :censored, where("censored=TRUE AND (spam is NULL or spam=FALSE)")
  end

  def check_for_spam
    self.spam = self.censored = spam?
    nil  # returning false here will interrupt save
  end

  def censor!(as=nil)
    if as == :spam
      self.spam = self.censored = spam!
    else
      self.censored = true
    end
    save
  end

  def uncensor!(as=nil)
    if as == :ham
      self.spam = self.censored = ham!
    else
      self.censored = false
    end
    save
  end

end