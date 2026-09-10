# frozen_string_literal: true
require "nokogiri"
require "json"
require "uri"
require "addressable/uri"
require "yaml"
require "set"
root = "_site"
failures = []
files = Dir.glob("#{root}/**/*").select { |p| File.file?(p) }.to_set
html_files = files.select { |p| p.end_with?(".html") }
abort "No built HTML found; run bundle exec jekyll build first" if html_files.empty?
documents = html_files.to_h { |p| [p, Nokogiri::HTML(File.read(p))] }
resolve = lambda do |url_path|
  relative = url_path.delete_prefix("/")
  stem = "#{root}/#{relative}"
  candidates = relative.end_with?("/") || relative.empty? ? ["#{stem}index.html"] : [stem, "#{stem}.html", "#{stem}/index.html"]
  candidates.find { |p| files.include?(p) }
end
documents.each do |file, doc|
  route = "/" + file.delete_prefix("#{root}/").sub(/index\.html$/, "").sub(/\.html$/, "")
  route = "/404.html" if file.end_with?("/404.html")
  failures << "#{file}: expected exactly one h1" unless doc.css("h1").length == 1
  failures << "#{file}: missing description" if doc.at_css('meta[name="description"]')&.[]("content").to_s.empty?
  canonical = doc.at_css('link[rel="canonical"]')&.[]("href")
  failures << "#{file}: invalid canonical" unless canonical&.start_with?("https://dleontev.com/")
  doc.css("a").each do |a|
    name = a["aria-label"] || a.text.strip
    name = a.css("img").map { |i| i["alt"] }.join.strip if name.to_s.empty?
    failures << "#{file}: unnamed link #{a['href']}" if name.to_s.empty?
  end
  doc.css("img").each do |img|
    failures << "#{file}: image lacks dimensions #{img['src']}" unless img["width"].to_i > 0 && img["height"].to_i > 0
    failures << "#{file}: image lacks alt attribute" unless img.key?("alt")
  end
  refs = doc.css("[href], [src]").flat_map { |e| [e["href"],e["src"]] }.compact
  refs += doc.css("[srcset]").flat_map { |e| e["srcset"].split(",").map { |part| part.strip.split.first } }
  refs += doc.css('meta[property="og:image"]').map { |e| e["content"] }
  refs.each do |value|
    next if value.to_s.empty?
    begin
      url = Addressable::URI.join("https://dleontev.com#{route}", value).normalize
      next unless ["http", "https"].include?(url.scheme) && ["dleontev.com","www.dleontev.com"].include?(url.host)
      target = resolve.call(URI::DEFAULT_PARSER.unescape(url.path))
      failures << "#{file}: missing target #{value}" unless target
      if target && url.fragment && !url.fragment.empty? && documents[target]
        id = URI::DEFAULT_PARSER.unescape(url.fragment)
        failures << "#{file}: missing anchor #{value}" unless documents[target].css("[id]").any? { |e| e["id"] == id }
      end
    rescue URI::InvalidURIError, Addressable::URI::InvalidURIError
      failures << "#{file}: invalid URL #{value}"
    end
  end
end
index = JSON.parse(File.read("#{root}/search.json"))
index.each do |post|
  failures << "Invalid search entry" unless post["title"].is_a?(String) && post["tags"].is_a?(Array)
  uri = URI.parse(post.fetch("url"))
  failures << "Search target missing: #{post['url']}" unless uri.host || resolve.call(uri.path)
end
certs = YAML.safe_load_file("_data/certifications.yml")
certs.each do |cert|
  failures << "Missing certification image #{cert['image']}" unless resolve.call(cert["image"])
  failures << "Bad certification verification link" unless cert["verification_url"].start_with?("https://")
  failures << "Nonstandard canonical image name #{cert['image']}" unless File.basename(cert["image"]).match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\.png\z/)
end
home = documents.fetch("#{root}/index.html")
about = documents.fetch("#{root}/about/index.html")
home_links = home.css(".cert-link").map { |e| e["href"] }.sort
about_links = about.css(".certification-list a").map { |e| e["href"] }.sort
failures << "Certification views disagree" unless home_links == about_links && home_links.length == certs.length
YAML.safe_load_file("_data/asset-aliases.yml").each do |old_path,new_path|
  failures << "Missing legacy/canonical asset #{old_path}" unless resolve.call(old_path) && resolve.call(new_path)
end
if failures.any?
  warn failures.uniq.join("\n")
  abort "#{failures.uniq.length} validation failures"
end
puts "Validated #{documents.length} HTML pages, #{index.length} search entries, and #{certs.length} certifications."
