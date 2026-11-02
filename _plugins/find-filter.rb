# frozen_string_literal: true

# Bridge single-document lookups while github-pages pins Jekyll 3.10.
# Jekyll 4.1+ supplies its own find filter; leave that implementation intact.
unless Jekyll::Filters.method_defined?(:find)
  module JekyllFindCompatibility
    def find(input, property, value)
      where(input, property, value).first
    end
  end
  Liquid::Template.register_filter(JekyllFindCompatibility)
end
