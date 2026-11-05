# frozen_string_literal: true

# Shared helpers for the af/xh machine-translation pipeline (plan U3).
# Pure Ruby + Psych: no Rails, no DB. Used by extract.rb, merge.rb,
# validate.rb and spec/i18n/translation_integrity_spec.rb.
require "yaml"
require "json"
require "set"
require "fileutils"

module CctI18n
  MODULES = %w(
    core admin proposals participatory_processes budgets meetings comments
    forms surveys verifications accountability api assemblies blogs debates
    pages system
  ).freeze

  LOCALES = %w(af xh).freeze

  # Path segments are joined with this separator in chunk files.
  SEP = "."

  INTERPOLATION_RE = /%\{[^}]+\}|%<[^>]+>[-+ 0#]*\d*(?:\.\d+)?[a-zA-Z]/
  STRFTIME_RE = /%[-_0^#:]?[a-zA-Z](?![a-zA-Z])/
  HTML_TAG_RE = %r{</?([a-zA-Z][a-zA-Z0-9-]*)\b[^<>]*>}

  module_function

  # Loads a locale YAML file as data (no arbitrary object instantiation).
  def load_yaml(path)
    YAML.safe_load_file(path, permitted_classes: [Symbol, Date, Time], aliases: true)
  end

  # Yields [path_array, value] for every leaf. Hashes and arrays are walked.
  def each_leaf(node, path = [], &block)
    case node
    when Hash
      node.each { |k, v| each_leaf(v, path + [k], &block) }
    when Array
      node.each_with_index { |v, i| each_leaf(v, path + [i], &block) }
    else
      yield path, node
    end
  end

  def path_key(path)
    path.map(&:to_s).join(SEP)
  end

  # Flat { "a.b.c" => leaf } for the tree under the top-level locale key.
  def flatten(tree)
    out = {}
    each_leaf(tree) { |p, v| out[path_key(p)] = v }
    out
  end

  # Strings worth sending to a translator. Everything else is copied verbatim.
  def translatable?(value)
    return false unless value.is_a?(String)
    return false if value.strip.empty?

    stripped = value.gsub(INTERPOLATION_RE, "").gsub(HTML_TAG_RE, "").gsub(STRFTIME_RE, "")
    stripped.match?(/[a-zA-Z]{2,}/)
  end

  def interpolations(str)
    str.to_s.scan(INTERPOLATION_RE).sort
  end

  def strftime_tokens(str)
    str.to_s.gsub(INTERPOLATION_RE, "").scan(STRFTIME_RE).sort
  end

  def html_tags(str)
    str.to_s.scan(HTML_TAG_RE).flatten.map(&:downcase).sort
  end

  # Compares one translated leaf against its English source. Returns an
  # array of human-readable problems (empty when fine).
  def leaf_problems(en_value, tr_value)
    problems = []
    if en_value.is_a?(String)
      unless tr_value.is_a?(String)
        return ["expected String, got #{tr_value.class}"]
      end
      problems << "empty translation" if tr_value.strip.empty? && !en_value.strip.empty?
      if interpolations(en_value) != interpolations(tr_value)
        problems << "interpolations #{interpolations(en_value)} != #{interpolations(tr_value)}"
      end
      if strftime_tokens(en_value) != strftime_tokens(tr_value)
        problems << "format tokens #{strftime_tokens(en_value)} != #{strftime_tokens(tr_value)}"
      end
      if html_tags(en_value) != html_tags(tr_value)
        problems << "html tags #{html_tags(en_value)} != #{html_tags(tr_value)}"
      end
    elsif en_value != tr_value
      problems << "non-string value changed (#{en_value.inspect} -> #{tr_value.inspect})"
    end
    problems
  end

  # Full-file comparison. en_tree / tr_tree are the hashes under "en" / locale.
  # Returns { missing: [...], extra: [...], leaves: { key => [problems] } }.
  def compare_trees(en_tree, tr_tree)
    en_flat = flatten(en_tree)
    tr_flat = flatten(tr_tree || {})
    leaves = {}
    en_flat.each do |k, v|
      next unless tr_flat.key?(k)

      probs = leaf_problems(v, tr_flat[k])
      leaves[k] = probs unless probs.empty?
    end
    {
      missing: (en_flat.keys - tr_flat.keys).sort,
      extra: (tr_flat.keys - en_flat.keys).sort,
      leaves: leaves
    }
  end

  # Rebuilds a locale tree from the English tree, replacing translatable
  # string leaves with entries from +translations+ (flat key => string).
  # Keys/structure/non-string leaves always come from English, so the key set
  # matches by construction. Missing translations fall back to English and are
  # reported via +missing+.
  def rebuild(node, translations, missing, path = [])
    case node
    when Hash
      node.each_with_object({}) { |(k, v), h| h[k] = rebuild(v, translations, missing, path + [k]) }
    when Array
      node.each_with_index.map { |v, i| rebuild(v, translations, missing, path + [i]) }
    else
      key = path_key(path)
      if translatable?(node)
        if translations.key?(key)
          translations[key]
        else
          missing << key
          node
        end
      else
        node
      end
    end
  end

  # Path to the English source for +mod+: either EN_DIR/<mod>.yml or the
  # installed gem's config/locales/en.yml.
  def en_source(mod, en_dir = nil)
    return File.join(en_dir, "#{mod}.yml") if en_dir

    gem_name = "decidim-#{mod}"
    spec = Gem.loaded_specs[gem_name] || Gem::Specification.find_by_name(gem_name)
    File.join(spec.full_gem_path, "config", "locales", "en.yml")
  rescue Gem::MissingSpecError
    nil
  end

  def translation_file(root, locale, mod)
    File.join(root, locale, "#{mod}.yml")
  end

  HEADER = <<~TXT
    # Machine-translated (AI) from the Decidim 0.32.2 English locale for the
    # City of Cape Town demo. NOT reviewed by a first-language speaker.
    # Generated by script/i18n (plan U3); see docs/i18n-glossary.md.
  TXT

  def dump_locale(locale, tree, header: nil)
    yaml = YAML.dump({ locale => tree }, line_width: -1)
    header ? "#{header}#{yaml}" : yaml
  end
end
