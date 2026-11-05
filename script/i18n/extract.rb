# frozen_string_literal: true

# Flattens the English Decidim locale files into translation chunks.
#
#   ruby script/i18n/extract.rb EN_DIR OUT_DIR [MAX_KEYS] [MAX_CHARS]
#
# EN_DIR holds <module>.yml copies of each gem's config/locales/en.yml, e.g.
#   docker run --rm decidim-demo:latest cat \
#     /usr/local/bundle/ruby/3.4.0/gems/decidim-core-0.32.2/config/locales/en.yml > en/core.yml
# OUT_DIR receives <module>-NN.json files ({ "dotted.key" => "English" }) with
# only translatable strings, plus manifest.json.
require_relative "common"

en_dir, out_dir, max_keys, max_chars = ARGV
abort "usage: extract.rb EN_DIR OUT_DIR [MAX_KEYS] [MAX_CHARS]" unless en_dir && out_dir
max_keys = (max_keys || 350).to_i
max_chars = (max_chars || 16_000).to_i

Dir.mkdir(out_dir) unless Dir.exist?(out_dir)
manifest = {}

CctI18n::MODULES.each do |mod|
  file = File.join(en_dir, "#{mod}.yml")
  next unless File.exist?(file)

  tree = CctI18n.load_yaml(file).fetch("en")
  flat = {}
  CctI18n.each_leaf(tree) do |path, value|
    if path.any? { |seg| seg.to_s.include?(CctI18n::SEP) }
      abort "#{mod}: key segment contains '#{CctI18n::SEP}': #{path.inspect}"
    end
    key = CctI18n.path_key(path)
    abort "#{mod}: duplicate flattened key #{key}" if flat.key?(key)

    flat[key] = value if CctI18n.translatable?(value)
  end

  chunks = [{}]
  size = 0
  flat.each do |k, v|
    if chunks.last.size >= max_keys || (size + k.size + v.size > max_chars && chunks.last.any?)
      chunks << {}
      size = 0
    end
    chunks.last[k] = v
    size += k.size + v.size
  end

  names = chunks.each_with_index.map do |chunk, i|
    name = format("%<mod>s-%<n>02d", mod: mod, n: i + 1)
    File.write(File.join(out_dir, "#{name}.json"), JSON.pretty_generate(chunk))
    name
  end
  manifest[mod] = { "keys" => flat.size, "chunks" => names }
  puts format("%-24s %5d translatable keys, %2d chunks", mod, flat.size, names.size)
end

File.write(File.join(out_dir, "manifest.json"), JSON.pretty_generate(manifest))
puts "total: #{manifest.values.sum { |m| m['keys'] }} keys, #{manifest.values.sum { |m| m['chunks'].size }} chunks"
