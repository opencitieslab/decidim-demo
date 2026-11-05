# frozen_string_literal: true

# Merges translated chunk JSONs back into Decidim-shaped locale files.
#
#   ruby script/i18n/merge.rb EN_DIR TRANSLATED_DIR DEST_ROOT [module ...]
#
# TRANSLATED_DIR/<locale>/<module>-NN.json are the agents' outputs.
# Writes DEST_ROOT/<locale>/<module>.yml (e.g. config/locales/decidim/af/core.yml).
# Structure, keys and non-translatable leaves come from English; a module is
# only written when every one of its translatable keys has a translation.
require_relative "common"

en_dir, tr_dir, dest_root, *mods = ARGV
abort "usage: merge.rb EN_DIR TRANSLATED_DIR DEST_ROOT [module ...]" unless en_dir && tr_dir && dest_root
mods = CctI18n::MODULES if mods.empty?
failed = false

CctI18n::LOCALES.each do |locale|
  mods.each do |mod|
    en_file = CctI18n.en_source(mod, en_dir)
    next unless en_file && File.exist?(en_file)

    translations = {}
    Dir.glob(File.join(tr_dir, locale, "#{mod}-[0-9][0-9].json")).sort.each do |f|
      translations.merge!(JSON.parse(File.read(f, encoding: "UTF-8")))
    end
    en_tree = CctI18n.load_yaml(en_file).fetch("en")
    missing = []
    tree = CctI18n.rebuild(en_tree, translations, missing)
    if missing.any?
      warn format("%-3s %-24s SKIPPED: %d keys untranslated (e.g. %s)", locale, mod, missing.size, missing.first)
      failed = true
      next
    end

    out = CctI18n.translation_file(dest_root, locale, mod)
    FileUtils.mkdir_p(File.dirname(out))
    File.write(out, CctI18n.dump_locale(locale, tree, header: CctI18n::HEADER))
    puts format("%-3s %-24s written (%d translated keys)", locale, mod, translations.size)
  end
end

exit(failed ? 1 : 0)
