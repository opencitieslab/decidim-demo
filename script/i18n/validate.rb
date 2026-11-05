# frozen_string_literal: true

# Validates the committed af/xh Decidim locale files against English.
#
#   ruby script/i18n/validate.rb [LOCALE_ROOT] [EN_DIR]
#
# LOCALE_ROOT defaults to config/locales/decidim. EN_DIR (optional) holds
# <module>.yml copies of the English files; without it the installed gems'
# config/locales/en.yml are used. For each module/locale present it checks:
# YAML parses with the right top-level key, identical key set (incl. plural
# sub-keys), identical %{..} placeholders, strftime tokens and HTML tag names.
require_relative "common"

root = ARGV[0] || File.expand_path("../../config/locales/decidim", __dir__)
en_dir = ARGV[1]
total_problems = 0

CctI18n::LOCALES.each do |locale|
  CctI18n::MODULES.each do |mod|
    file = CctI18n.translation_file(root, locale, mod)
    next unless File.exist?(file)

    en_file = CctI18n.en_source(mod, en_dir)
    unless en_file && File.exist?(en_file)
      abort "cannot locate English source for #{mod}; pass EN_DIR or run under `bundle exec`"
    end
    data = begin
      CctI18n.load_yaml(file)
    rescue Psych::Exception => e
      puts "#{file}: YAML error #{e.message}"
      total_problems += 1
      next
    end
    unless data.is_a?(Hash) && data.keys == [locale]
      puts "#{file}: top-level key must be #{locale.inspect}, got #{data.is_a?(Hash) ? data.keys.inspect : data.class}"
      total_problems += 1
      next
    end

    result = CctI18n.compare_trees(CctI18n.load_yaml(en_file).fetch("en"), data[locale])
    count = result[:missing].size + result[:extra].size + result[:leaves].size
    total_problems += count
    puts format("%-3s %-24s %s", locale, mod, count.zero? ? "OK (#{CctI18n.flatten(data[locale]).size} keys)" : "#{count} problems")
    result[:missing].first(10).each { |k| puts "    missing: #{k}" }
    result[:extra].first(10).each { |k| puts "    extra:   #{k}" }
    result[:leaves].first(20).each { |k, probs| puts "    #{k}: #{probs.join('; ')}" }
  end
end

puts total_problems.zero? ? "ALL CLEAN" : "#{total_problems} problems"
exit(total_problems.zero? ? 0 : 1)
