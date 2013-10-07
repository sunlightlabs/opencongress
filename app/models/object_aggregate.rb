class ObjectAggregate < ActiveRecord::Base
  belongs_to :aggregatable, :polymorphic => true

  def self.popular(viewable_type, seconds = Settings.default_count_time, limit = 20, congress = Settings.default_congress, frontpage_hot = false)
    if %W(Senator Representative).include? viewable_type
      associated_class = Person
    else
      associated_class = Object.const_get(viewable_type)
    end

    where_clause = ""
    if (viewable_type == 'Bill')
      where_clause = "WHERE bills.session=#{congress}"
      where_clause += " AND bills.is_frontpage_hot = 't'" if frontpage_hot
    elsif (viewable_type == 'Senator')
      where_clause = "WHERE people.title = 'Sen.'"
      viewable_type = 'Person'
    elsif (viewable_type == 'Representative')
      where_clause = "Where people.title = 'Rep.'"
      viewable_type = 'Person'
    end

    associated_class.find_by_sql(["SELECT #{associated_class.table_name}.*,
                                          most_viewed.view_count AS view_count
                                   FROM #{associated_class.table_name}
                                   INNER JOIN
                                   (SELECT object_aggregates.aggregatable_id,
                                           sum(object_aggregates.page_views_count) AS view_count
                                    FROM object_aggregates
                                    WHERE object_aggregates.date >= ? AND
                                          object_aggregates.aggregatable_type = ?
                                    GROUP BY object_aggregates.aggregatable_id
                                    ORDER BY view_count DESC) most_viewed
                                   ON #{associated_class.table_name}.id=most_viewed.aggregatable_id
                                   #{where_clause}
                                   ORDER BY view_count DESC LIMIT ?",
                                  seconds.ago, viewable_type, limit])
  end
end