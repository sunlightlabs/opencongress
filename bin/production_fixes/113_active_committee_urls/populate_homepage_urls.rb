#!/usr/bin/env ruby

urls = []
File.open('urls.txt', 'r').each {|line| urls.push(line) }
committees = YAML.load('committees.yml')
committees.each_with_index do |name,i|
  cs = Committees.where(name:name,active:true)
  cs.each do |object|
    object.homepage_url = urls[i].strip
    object.save
  end
end