object false

child @bills do
  extends "bill/show"
end

code(:total_pages) do
    @bills.total_pages
end

# i{:simple => {:except => [:rolls, :hot_bill_category_id]},
