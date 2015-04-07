#!/usr/bin/env ruby

require 'csv'
require File.expand_path('../../config/environment', __FILE__)
<<<<<<< HEAD
require 'fileutils'

=======
>>>>>>> added political notebook export script
ENV["RAILS_ENV"] ||= "development"


def to_csv(notebook)
<<<<<<< HEAD
  p "exporting notebook #{notebook.id}"
  attrs = group_and_user_attr(notebook)
  CSV.open("./data/#{attrs[:name]}", 'wb', write_headers: true, headers: attrs[:headers]) do |csv|
    notebook.notebook_items.each do |item|
      if notebook.group_id
        csv << [notebook.group.name, (item.type.gsub('Notebook', '') if item.type), item.title, item.url, item.date, item.description]
      else
        csv << [(item.type.gsub('Notebook', '') if item.type), item.title, item.url, item.date, item.description]
      end
=======
  CSV.open("./data/#{name_csv(notebook)}", 'wb') do |csv|
    csv << ['type', 'title', 'url', 'date', 'description']
    notebook.notebook_items.each do |item|
      puts notebook.id
      csv << [(item.type.gsub('Notebook', '') if item.type), item.title, item.url, item.date, item.description]
>>>>>>> added political notebook export script
    end
  end
end

def name_csv(notebook)
<<<<<<< HEAD
  notebook.group_id ? "groups/group-#{notebook.group_id}.csv" : "users/user-#{notebook.user_id}.csv"
end

def group_and_user_attr(notebook)
  if notebook.group_id
    {
      name: "groups/group-#{notebook.group_id}.csv", 
      headers: ['name', 'type', 'title', 'url', 'date', 'description']
    }
  else
    {
      name: "users/user-#{notebook.user_id}.csv",
      headers: ['type', 'title', 'url', 'date', 'description']
    }
  end
=======
  notebook.group_id ? "group-#{notebook.group_id}.csv" : "user-#{notebook.user_id}.csv"
>>>>>>> added political notebook export script
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

<<<<<<< HEAD
FileUtils.mkdir_p('./data/groups')
FileUtils.mkdir_p('./data/users')

=======
>>>>>>> added political notebook export script
[get_user_notebooks, get_group_notebooks].each do |notebook_parent|
  notebook_parent.each { |notebook| to_csv(notebook) }
end
