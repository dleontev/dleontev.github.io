# frozen_string_literal: true
require "json"
require "fileutils"
require "pathname"

module ValidationManifest
  def self.path(site)
    File.join(site.source, ".validation", "manifest.json")
  end

  def self.write(site)
    pages = []
    redirects = []
    owner = site.config.fetch("author").fetch("name")
    documents = site.pages + site.collections.values.flat_map(&:docs)
    documents.select { |document| document.write? && document.output_ext == ".html" }
             .sort_by(&:relative_path).each do |document|
      data = document.data
      source = document.relative_path.tr("\\", "/")
      route = document.url
      output = Pathname.new(document.destination(site.dest))
                       .relative_path_from(Pathname.new(site.dest)).to_s.tr("\\", "/")
      if data["redirect_target"]
        redirects << {source: source, url: route, output: output, target: data["redirect_target"]}
        next
      end

      title = data["title"]
      unless title.is_a?(String) && !title.strip.empty?
        raise Jekyll::Errors::FatalException, "#{source}: missing a usable title"
      end
      pages << {
        source: source, url: route, output: output, title: title,
        collection: document.respond_to?(:collection) ? document.collection.label : nil,
        browserTitle: title.include?(owner) ? title : "#{title} | #{owner}",
        section: route == "/" ? "Home" : {"about" => "About", "blog" => "Blog", "projects" => "Projects"}[route.split("/")[1]],
        article: data["article"], related_posts: data["related_posts"] || [], related_project: data["related_project"],
        tags: data["tags"], status: data["status"], noindex: data["noindex"] == true,
        sitemap: data["sitemap"] != false, last_modified_at: data["last_modified_at"]&.to_s
      }
    end
    manifest = {
      schema_version: 1, source_root: site.source, destination: site.dest,
      pages: pages, redirects: redirects,
      certifications: site.data.fetch("certifications", []), skills: site.data.fetch("skills", [])
    }
    FileUtils.mkdir_p(File.dirname(path(site)))
    File.write(path(site), JSON.pretty_generate(manifest))
    Jekyll.logger.info "Validation manifest:", "#{pages.length} HTML pages and #{redirects.length} redirects."
  end
end

# A failed rebuild must not leave a previous successful build's inventory usable.
Jekyll::Hooks.register :site, :after_reset do |site|
  FileUtils.rm_f(ValidationManifest.path(site))
end

Jekyll::Hooks.register :site, :post_write do |site|
  ValidationManifest.write(site)
end
