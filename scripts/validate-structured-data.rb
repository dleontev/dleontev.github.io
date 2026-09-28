# frozen_string_literal: true
require 'json'
require 'yaml'

def validate_structured_data(documents, manifest)
  config = YAML.safe_load_file('_config.yml')
  home = "#{config.fetch('url')}#{config.fetch('baseurl')}/"
  person_id = "#{home}#person"
  website_id = "#{home}#website"
  profile_url = "#{home}about/"
  failures = []
  documents.each do |file, doc|
    scripts = doc.css('script[type="application/ld+json"]')
    if doc.at_css('meta[name="robots"]')&.[]('content').to_s.include?('noindex')
      failures << "#{file}: utility page should omit structured data" unless scripts.empty?
      next
    end
    unless scripts.length == 1
      failures << "#{file}: expected one structured-data graph"
      next
    end
    begin
      data = JSON.parse(scripts.first.content)
      raise 'wrong schema context' unless data.fetch('@context') == 'https://schema.org'
      graph = data.fetch('@graph')
      ids = graph.map { |node| node.fetch('@id') }
      raise 'duplicate entity IDs' unless ids.uniq == ids
      nodes = graph.to_h { |node| [node.fetch('@id'), node] }
      canonical = doc.at_css('link[rel="canonical"]')['href']
      person = nodes.fetch(person_id)
      website = nodes.fetch(website_id)
      page = nodes.fetch("#{canonical}#webpage")
      raise 'wrong person identity' unless person['@type'] == 'Person' && person['name'] == config.dig('author', 'name') && person['url'] == profile_url
      raise 'wrong professional role' unless person['jobTitle'] == config.dig('author', 'job_title')
      profiles = person.fetch('sameAs')
      raise 'profile links disagree with visible links' unless profiles.length == 2 && profiles.all? { |url| doc.css('a[href]').any? { |a| a['href'].delete_suffix('/') == url.delete_suffix('/') } }
      raise 'website has wrong publisher' unless website['@type'] == 'WebSite' && website['url'] == home && website.dig('publisher', '@id') == person_id
      raise 'page has wrong canonical or website' unless page['url'] == canonical && page.dig('isPartOf', '@id') == website_id

      profile_page = [home, profile_url].include?(canonical)
      if profile_page
        raise 'professional role differs from visible biography' unless doc.at_css('main').text.include?(person['jobTitle'])
        raise 'profile has wrong subject' unless page.dig('mainEntity', '@id') == person_id
        expected_type = canonical == profile_url ? 'ProfilePage' : 'WebPage'
        raise 'wrong profile page type' unless page['@type'] == expected_type
        raise 'missing skill context' if person.fetch('knowsAbout').empty?
        credentials = person.fetch('hasCredential')
        expected = manifest.fetch('certifications')
        raise 'credential count differs from visible content' unless credentials.length == expected.length
        credentials.zip(expected).each do |credential, cert|
          raise 'credential disagrees with source data' unless credential['@type'] == 'EducationalOccupationalCredential' && credential['name'] == cert['title'] && credential['url'] == cert['verification_url'] && credential.dig('recognizedBy', 'name') == cert['issuer']
          raise 'credential has no visible verification link' unless doc.css('a[href]').any? { |a| a['href'] == credential['url'] }
        end
      elsif person.key?('hasCredential') || person.key?('knowsAbout')
        raise 'detailed credentials and skills belong on profile pages'
      end

      entry = manifest.fetch('pages').find { |item| "#{config.fetch('url')}#{item['url']}" == canonical }
      next unless entry && entry['source'].start_with?('_posts/', '_projects/')
      article = entry['source'].start_with?('_posts/')
      work_id = "#{canonical}##{article ? 'article' : 'project'}"
      work = nodes.fetch(work_id)
      raise 'page does not identify its work' unless page.dig('mainEntity', '@id') == work_id
      raise 'work has wrong creator' unless work.dig(article ? 'author' : 'creator', '@id') == person_id
      raise 'work does not identify its canonical page' unless work['url'] == canonical && work.dig('mainEntityOfPage', '@id') == page['@id']
      raise 'work title differs from visible heading' unless work[article ? 'headline' : 'name'] == doc.at_css('h1').text
      if article
        raise 'wrong article type or date' unless work['@type'] == 'BlogPosting' && work['datePublished'] == doc.at_css('article time')['datetime']
      else
        raise 'project status differs from published status' unless work['@type'] == 'CreativeWork' && work['creativeWorkStatus'] == entry['status'] && doc.at_css('main').text.include?(entry['status'])
      end
    rescue JSON::ParserError, KeyError, TypeError, NoMethodError, RuntimeError => error
      failures << "#{file}: invalid structured data (#{error.message})"
    end
  end
  failures
end
