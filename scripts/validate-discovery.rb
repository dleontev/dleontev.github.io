# frozen_string_literal: true
require 'nokogiri'
require 'yaml'
require 'uri'
require 'date'
require 'set'

def validate_discovery(documents, manifest, root)
  config = YAML.safe_load_file('_config.yml')
  home = "#{config.fetch('url')}#{config.fetch('baseurl')}/"
  failures = []
  expected = {}
  entries = manifest.fetch('pages').to_h { |page| [URI.join(home, page.fetch('url')).to_s, page] }
  documents.each_value do |doc|
    next if doc.at_css('meta[name="robots"]')&.[]('content').to_s.match?(/\bnoindex\b/i)
    next if doc.at_css('meta[http-equiv="refresh"]')
    canonical = doc.at_css('link[rel="canonical"]')&.[]('href')
    entry = entries[canonical]
    next if entry && (entry['noindex'] || entry['sitemap'] == false)
    expected[canonical] = entry
  end

  begin
    sitemap = Nokogiri::XML(File.read("#{root}/sitemap.xml")) { |parser| parser.strict.nonet }
    namespace = 'http://www.sitemaps.org/schemas/sitemap/0.9'
    raise 'expected a sitemap urlset' unless sitemap.root&.name == 'urlset' && sitemap.root.namespace&.href == namespace
    urls = sitemap.xpath('/s:urlset/s:url', 's' => namespace)
    locations = urls.map do |node|
      loc = node.xpath('s:loc', 's' => namespace)
      raise 'each entry must have exactly one loc' unless loc.length == 1
      location = loc.first.text.strip
      uri = URI.parse(location)
      raise "noncanonical sitemap URL: #{location}" unless location.start_with?(home) && uri.scheme == 'https' && !uri.query && !uri.fragment && !uri.userinfo
      modified = node.xpath('s:lastmod', 's' => namespace)
      raise "duplicate lastmod: #{location}" if modified.length > 1
      unless modified.empty?
        declared = expected[location]&.fetch('last_modified_at', nil)
        raise "lastmod needs an explicit source date: #{location}" unless declared
        raise "lastmod differs from source date: #{location}" unless Date.iso8601(modified.first.text) == Date.parse(declared)
      end
      location
    end
    failures << 'sitemap.xml: duplicate URLs' unless locations.uniq == locations
    (expected.keys.to_set - locations.to_set).each { |url| failures << "sitemap.xml: missing indexable page #{url}" }
    (locations.to_set - expected.keys.to_set).each { |url| failures << "sitemap.xml: unexpected, utility, redirect, or noncanonical URL #{url}" }
  rescue Errno::ENOENT, Nokogiri::XML::SyntaxError, URI::InvalidURIError, ArgumentError, RuntimeError => error
    failures << "sitemap.xml: #{error.message}"
  end

  begin
    robots = File.read("#{root}/robots.txt")
    directives = robots.lines.map { |line| line.sub(/#.*/, '').strip }.reject(&:empty?).map do |line|
      key, value = line.split(':', 2)
      raise "invalid directive: #{line}" unless value
      [key.downcase, value.strip]
    end
    # Keep this check aligned with the owner's explicitly open crawler policy.
    required = [['user-agent', '*'], ['allow', '/'], ['sitemap', "#{home}sitemap.xml"]]
    failures << 'robots.txt: expected the open crawler policy and canonical sitemap location' unless directives == required
  rescue Errno::ENOENT, RuntimeError => error
    failures << "robots.txt: #{error.message}"
  end
  failures
end
