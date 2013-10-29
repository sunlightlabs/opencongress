##
# Filters a user scope to that which can be rightly viewed by the passed-in observer.
#
# 1. scope receives a relation and an options hash:
#    - :property => the property that should be validated for visibility
#    - :observer => the observer
# 2. fetch all objects where given property is public
# 3. fetch all of observer's friends where that property is visible to friends.
# 4. return the combined set of objects.
##

class VisibleByPrivacyOptionQuery
  def initialize(relation, options = {})
    # relation is optional and ruby sucks
    if relation.is_a? Hash
      options = relation
      relation = User.scoped
    end
    @observer = options[:observer]
    @property = options[:property]
    @statuses = PrivacyOption.get_option_values

    raise ArgumentError, 'Specified property is not a valid privacy option' unless PrivacyOption.get_option_keys.include?(@property)
    @relation = relation
      .includes(:friends)
      .includes(:privacy_option)
      .where("privacy_options.#{@property} = :public_value
             OR (privacy_options.#{@property} = :friends_value
                 AND friends.friend_id = :observer_id)
             OR users.id = :observer_id", {
        :public_value => @statuses[:public],
        :friends_value => @statuses[:friends],
        :observer_id => (@observer.id rescue 0)
      })

    unless options[:excludes].nil?
      excludes options[:excludes]
    end

    self
  end

  def with_relations
    @relation = @relation.includes(:comments, :friends, :bill_votes, :person_approvals)
    self
  end

  def excludes(objects)
    return self if (objects.nil? or objects == :false)
    if objects.respond_to? :collect
      ids = objects.collect(&:id)
    else
      ids = [objects.id]
    end
    @relation = @relation.where("users.id not in(?)", ids)
    self
  end

  def find_each(&block)
    @relation.each(&block)
  end
  alias_method :map, :find_each
  alias_method :each, :find_each

  # returns an AR relation, breaking chainability of query methods.
  def scoped
    return @relation.scoped
  end
  alias_method :all, :scoped

end