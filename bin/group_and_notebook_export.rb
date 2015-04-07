#!/usr/bin/env ruby

require 'csv'
require File.expand_path('../../config/environment', __FILE__)
ENV["RAILS_ENV"] ||= "development"


def to_csv(notebook)
  CSV.open("./data/#{name_csv(notebook)}", 'wb') do |csv|
    csv << ['type', 'title', 'url', 'date', 'description']
    notebook.notebook_items.each do |item|
      puts notebook.id
      csv << [(item.type.gsub('Notebook', '') if item.type), item.title, item.url, item.date, item.description]
    end
  end
end

def name_csv(notebook)
  notebook.group_id ? "group-#{notebook.group_id}.csv" : "user-#{notebook.user_id}.csv"
end


def get_user_notebooks
  # Gets all political notebooks that have items in it
  PoliticalNotebook.includes(:notebook_items)
  .where("notebook_items.political_notebook_id is not null AND group_id IS null")
end


def get_group_notebooks
  PoliticalNotebook.includes(:notebook_items)
  .where("notebook_items.political_notebook_id IS NOT null AND group_id IS NOT null")
end

[get_user_notebooks, get_group_notebooks].each do |notebook_parent|
  notebook_parent.each { |notebook| to_csv(notebook) }
end
