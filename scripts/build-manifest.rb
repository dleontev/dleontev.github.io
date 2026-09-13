# frozen_string_literal: true
require 'yaml'
require 'json'
require 'date'
require 'fileutils'
config = YAML.safe_load_file('_config.yml')
pages = []
redirects = []
Dir.glob('{pages,_projects,_posts}/*').sort.each do |path|
  match = File.read(path).match(/\A---\s*\n(.*?)\n---\s*\n/m)
  next unless match
  data = YAML.safe_load(match[1], permitted_classes: [Date, Time])
  next if data['layout'].nil? && path.end_with?('.json')
  route = data['permalink']
  if path.start_with?('_posts/')
    slug = File.basename(path, '.md').sub(/^\d{4}-\d{2}-\d{2}-/, '')
    route = config.fetch('permalink').sub(':title', slug)
  end
  abort "Missing explicit route: #{path}" unless route
  if data['redirect_target']
    redirects << {url: route, target: data['redirect_target']}
    next
  end
  title = data.fetch('title') { abort "Missing explicit title: #{path}" }
  owner = config.fetch('author').fetch('name')
  pages << {source: path, url: route, title: title, browserTitle: title.include?(owner) ? title : "#{title} | #{owner}",
            section: route == '/' ? 'Home' : {'about'=>'About','blog'=>'Blog','projects'=>'Projects'}[route.split('/')[1]],
            article: data['article'], tags: data['tags'], status: data['status']}
end
FileUtils.mkdir_p('.validation')
File.write('.validation/manifest.json', JSON.pretty_generate({pages: pages, redirects: redirects,
  certifications: YAML.safe_load_file('_data/certifications.yml'), skills: YAML.safe_load_file('_data/skills.yml')}))
puts "Generated expectations for #{pages.length} pages and #{redirects.length} redirect."
