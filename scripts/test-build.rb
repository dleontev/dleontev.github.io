# frozen_string_literal: true
require "jekyll"
require "json"
require "yaml"
require "tmpdir"
require "fileutils"
require "stringio"
require "logger"
require_relative "../_plugins/validation-manifest"

ROOT = File.expand_path("..", __dir__)
CONFIG = YAML.safe_load_file(File.join(ROOT, "_config.yml"))

def assert(condition, message)
  raise message unless condition
end

def write(source, path, content)
  target = File.join(source, path)
  FileUtils.mkdir_p(File.dirname(target))
  File.write(target, content)
end

def fixture(overrides = {})
  FileUtils.mkdir_p(File.join(ROOT, ".validation"))
  Dir.mktmpdir("build-check-", File.join(ROOT, ".validation")) do |source|
    config = CONFIG.merge(
      "plugins" => [], "theme" => nil, "quiet" => true, "future" => false,
      "collections" => {"projects" => {"output" => true}, "private" => {"output" => false}},
      "defaults" => [{"scope" => {"path" => "pages"}, "values" => {"status" => "Inherited"}}]
    ).merge(overrides)
    write(source, "_config.yml", YAML.dump(config))
    site = Jekyll::Site.new(Jekyll.configuration(
      "source" => source, "destination" => File.join(source, "_site"),
      "config" => File.join(source, "_config.yml"), "quiet" => true
    ))
    yield source, site
  end
end

fixture do |source, site|
  write(source, "pages/guides/nested.md", "---\ntitle: Nested guide\n---\n# Nested guide\n")
  write(source, "_posts/2020-01-01-original.md", "---\ntitle: Custom route\npermalink: /guides/custom-route/\n---\n# Custom route\n")
  write(source, "_posts/2020-01-02-original-slug.md", "---\ntitle: Custom slug\nslug: chosen-slug\n---\n# Custom slug\n")
  write(source, "_projects/group/example.md", "---\ntitle: Nested project\npermalink: /projects/nested/\n---\n# Project\n")
  write(source, "_private/hidden.md", "---\ntitle: Private collection\n---\nHidden\n")
  write(source, "pages/unpublished.md", "---\ntitle: Unpublished\npublished: false\n---\nHidden\n")
  write(source, "pages/old.md", "---\ntitle: Old route\npermalink: /old/\nredirect_target: /\n---\nMoved\n")
  write(source, "search.json", "---\nlayout: null\n---\n[]\n")
  site.process
  manifest = JSON.parse(File.read(ValidationManifest.path(site)))
  pages = manifest.fetch("pages")
  by_source = pages.to_h { |page| [page.fetch("source"), page] }
  assert(by_source.fetch("_posts/2020-01-01-original.md")["url"] == "/guides/custom-route/", "Post permalink override was lost")
  assert(by_source.fetch("_posts/2020-01-02-original-slug.md")["url"] == "/blog/chosen-slug", "Post slug override was lost")
  nested = by_source.fetch("pages/guides/nested.md")
  assert(nested["url"] == "/pages/guides/nested", "Nested page route was lost: #{nested['url']}")
  assert(nested["status"] == "Inherited", "Front-matter defaults were lost")
  assert(by_source.fetch("_projects/group/example.md")["url"] == "/projects/nested/", "Nested collection document was lost")
  assert(pages.count { |page| page["collection"] == "posts" } == 2, "Post identity must come from the collection")
  assert(pages.length == 4, "Unpublished, private, redirect, or JSON content entered the HTML inventory")
  assert(manifest.fetch("redirects").map { |entry| entry["url"] } == ["/old/"], "Redirect inventory changed")
  (pages + manifest.fetch("redirects")).each do |page|
    assert(File.file?(File.join(site.dest, page.fetch("output"))), "Resolved output file missing for #{page['url']}")
  end
  assert(!File.exist?(File.join(site.dest, ".validation", "manifest.json")), "Validation data was published")
end
puts "PASS: resolved routes, nested content, metadata defaults, output filtering, and redirects"

fixture("collections_dir" => "content") do |source, site|
  write(source, "content/_posts/2020-01-01-relocated.md", "---
title: Relocated article
permalink: /guides/relocated/
---
# Article
")
  site.process
  pages = JSON.parse(File.read(ValidationManifest.path(site))).fetch("pages")
  assert(pages.length == 1 && pages.first["collection"] == "posts", "Relocated posts lost their collection identity")
  assert(pages.first["url"] == "/guides/relocated/", "Relocated post permalink was lost")
end
puts "PASS: relocated collections retain their identity and resolved URLs"

def expect_rejected(content, expected_error, label)
  fixture do |source, site|
    write(source, "broken.md", content)
    write(source, ".validation/manifest.json", '{"stale":true}')
    original_logger = Jekyll.logger
    begin
      Jekyll.logger = Logger.new(StringIO.new)
      site.process
    rescue StandardError => error
      assert(error.message.match?(expected_error), "#{label}: unexpected failure #{error.class}: #{error.message}")
      assert(!File.exist?(ValidationManifest.path(site)), "#{label}: stale manifest survived failed build")
    else
      raise "#{label}: invalid content was accepted"
    ensure
      Jekyll.logger = original_logger.writer
      Jekyll.logger.log_level = original_logger.level
    end
  end
  puts "PASS: #{label} fails the build and invalidates the previous inventory"
end

expect_rejected("---\ntitle: [broken\n---\n# Broken\n", /strict|syntax|parse|flow|expected/i, "malformed YAML")
expect_rejected("---\ntitle: Broken filter\n---\n{{ 'value' | missing_validation_filter }}\n", /undefined filter.*missing_validation_filter/i, "unknown Liquid filter")
expect_rejected("---\ntitle: Broken syntax\n---\n{{ 'value' trailing }}\n", /syntax|expected.*end_of_string/i, "invalid Liquid syntax")
