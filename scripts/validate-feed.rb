# frozen_string_literal: true
require 'nokogiri'
require 'yaml'
require 'uri'
require 'time'

def validate_feed(documents, manifest, root)
  config = YAML.safe_load_file('_config.yml')
  home = "#{config.fetch('url')}#{config.fetch('baseurl')}/"
  feed_url = URI.join(home, 'feed.xml').to_s
  author = config.fetch('author').fetch('name')
  failures = []
  documents.each do |file, doc|
    links = doc.css('head link[rel="alternate"][type="application/atom+xml"]')
    failures << "#{file}: missing or incorrect feed discovery" unless links.length == 1 && links.first['href'] == feed_url
    next unless doc.at_css('.site-footer')
    subscribe = doc.css('.site-footer .feed-subscribe a')
    failures << "#{file}: missing or incorrect Subscribe link" unless subscribe.length == 1 && URI.join(home, subscribe.first['href']).to_s == feed_url && subscribe.first.text.strip == 'Subscribe'
  end

  begin
    feed = Nokogiri::XML(File.read("#{root}/feed.xml")) { |parser| parser.strict.nonet }
    ns = {'a' => 'http://www.w3.org/2005/Atom'}
    raise 'expected an Atom feed' unless feed.root&.name == 'feed' && feed.root.namespace&.href == ns['a']
    raise 'incorrect feed identity or self link' unless feed.at_xpath('/a:feed/a:id', ns)&.text == feed_url && feed.at_xpath('/a:feed/a:link[@rel="self"]', ns)&.[]('href') == feed_url
    raise 'incorrect feed author' unless feed.at_xpath('/a:feed/a:author/a:name', ns)&.text == author

    pages = documents.values.to_h { |doc| [doc.at_css('link[rel="canonical"]')&.[]('href'), doc] }
    expected = manifest.fetch('pages').select { |page| page['source'].start_with?('_posts/') }.map do |page|
      canonical = URI.join(home, page.fetch('url')).to_s
      doc = pages.fetch(canonical)
      {url: canonical, title: doc.at_css('h1').text, published: Time.iso8601(doc.at_css('article time')['datetime'])}
    end.sort_by { |post| post[:published] }.reverse.first(config.dig('feed', 'posts_limit') || 10)
    entries = feed.xpath('/a:feed/a:entry', ns)
    raise 'feed does not cover the expected recent articles' unless entries.length == expected.length
    ids = entries.map { |entry| entry.at_xpath('a:id', ns)&.text.to_s }
    raise 'empty or duplicate article IDs' unless ids.none?(&:empty?) && ids.uniq == ids
    entries.zip(expected).each do |entry, post|
      link = entry.at_xpath('a:link[@rel="alternate"]', ns)
      raise 'feed article links or order differ from published articles' unless link&.[]('href') == post[:url]
      title = Nokogiri::HTML.fragment(entry.at_xpath('a:title', ns)&.text.to_s).text
      raise 'feed title differs from the published article' unless title == post[:title]
      raise 'incorrect article author' unless entry.at_xpath('a:author/a:name', ns)&.text == author
      raise 'incorrect article publication date' unless Time.iso8601(entry.at_xpath('a:published', ns).text) == post[:published]
      raise 'empty article content or summary' if entry.at_xpath('a:content', ns)&.text.to_s.strip.empty? || entry.at_xpath('a:summary', ns)&.text.to_s.strip.empty?
    end
    feed.xpath('/a:feed/a:updated | /a:feed/a:entry/a:updated', ns).each { |date| Time.iso8601(date.text) }
  rescue Errno::ENOENT, Nokogiri::XML::SyntaxError, KeyError, ArgumentError, NoMethodError, RuntimeError => error
    failures << "feed.xml: #{error.message}"
  end
  failures
end
