# frozen_string_literal: true
# Run from the repository root. Copy the output into dleontev/dleontev's README.
require "yaml"
certifications = YAML.safe_load_file("_data/certifications.yml")
puts "## 🎯 Certifications\n\n"
certifications.group_by { |cert| cert.fetch("group") }.each do |group, certs|
  puts "**#{group}**\n\n"
  certs.each { |cert| puts "- [#{cert.fetch("title")}](#{cert.fetch("verification_url")})" }
  puts
end
