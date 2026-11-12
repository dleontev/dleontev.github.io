source "https://rubygems.org"

gem "jekyll", "~> 4.4.1"
gem "webrick", "1.9.1"

# Octokit's Faraday 2 client uses this optional retry middleware.
gem "faraday-retry", "~> 2.4", require: "faraday/retry"

group :jekyll_plugins do
  gem "jekyll-default-layout", "~> 0.1.5"
  gem "jekyll-optional-front-matter", "~> 0.3.2"
  gem "jekyll-github-metadata", "~> 2.16"
  gem "jekyll-feed", "~> 0.17"
  gem "jemoji", "~> 0.13"
end

# Required directly by the content validators.
gem "addressable", "~> 2.8"
gem "nokogiri", "~> 1.18"

# Keep Ruby 3.3 and 3.4 standard-library dependencies consistent.
gem "logger", "1.6.5"
gem "csv", "3.3.2"
gem "base64", "0.2.0"
gem "bigdecimal", "3.1.9"
# Windows registry access must explicitly declare Fiddle on Ruby 3.4+.
gem "fiddle", "~> 1.1", platforms: [:mingw, :x64_mingw, :mswin]
gem "wdm", "0.2.0", platforms: [:mingw, :x64_mingw, :mswin]
