# frozen_string_literal: true

# Integrity checks for the machine-translated af/xh Decidim locale files
# (plan U3). Pure Ruby + YAML: no Rails boot, no database. The English source
# is read from the installed Decidim gems (Gem.loaded_specs under Bundler).
require "i18n"
require_relative "../../script/i18n/common"

LOCALE_ROOT = File.expand_path("../../config/locales/decidim", __dir__)

RSpec.describe "Decidim af/xh translation integrity" do
  describe "validator rules" do
    it "accepts a faithful translation" do
      expect(CctI18n.leaf_problems('Hi <a href="%{url}">%{name}</a>, %d %b', 'Hallo <a href="%{url}">%{name}</a>, %d %b')).to be_empty
    end

    it "rejects dropped or renamed placeholders" do
      expect(CctI18n.leaf_problems("%{count} proposals", "voorstelle")).not_to be_empty
      expect(CctI18n.leaf_problems("%{count} proposals", "%{aantal} voorstelle")).not_to be_empty
    end

    it "rejects changed HTML tags and format tokens" do
      expect(CctI18n.leaf_problems("<strong>Hi</strong>", "<b>Hallo</b>")).not_to be_empty
      expect(CctI18n.leaf_problems("%d/%m/%Y", "%d-%Y")).not_to be_empty
    end

    it "reports missing and extra keys" do
      result = CctI18n.compare_trees({ "a" => { "one" => "x", "other" => "y" } }, { "a" => { "other" => "y", "few" => "z" } })
      expect(result[:missing]).to eq(["a.one"])
      expect(result[:extra]).to eq(["a.few"])
    end
  end

  CctI18n::LOCALES.each do |locale|
    CctI18n::MODULES.each do |mod|
      describe "#{locale}/#{mod}.yml" do
        let(:file) { CctI18n.translation_file(LOCALE_ROOT, locale, mod) }
        let(:en_file) { CctI18n.en_source(mod) }
        let(:data) { CctI18n.load_yaml(file) }
        let(:en_tree) { CctI18n.load_yaml(en_file).fetch("en") }
        let(:result) { CctI18n.compare_trees(en_tree, data[locale]) }

        it "exists and parses as YAML with a single top-level #{locale} key" do
          expect(en_file).not_to be_nil, "decidim-#{mod} gem not loaded"
          expect(File).to exist(file)
          expect(data.keys).to eq([locale])
        end

        it "has exactly the English key set (including plural sub-keys)" do
          expect(result[:missing]).to be_empty, "missing: #{result[:missing].first(10)}"
          expect(result[:extra]).to be_empty, "extra: #{result[:extra].first(10)}"
        end

        it "keeps placeholders, format tokens and HTML tag names" do
          expect(result[:leaves]).to be_empty, result[:leaves].first(10).map { |k, p| "#{k}: #{p.join('; ')}" }.join("\n")
        end
      end
    end

    describe "#{locale} interpolation at runtime" do
      let(:backend) do
        I18n::Backend::Simple.new.tap do |b|
          b.load_translations(*Dir[File.join(LOCALE_ROOT, locale, "*.yml")])
        end
      end

      it "interpolates %{organization} in a translated string" do
        text = backend.translate(locale.to_sym, "decidim.accessibility.logo", organization: "Stad Kaapstad")
        expect(text).to include("Stad Kaapstad")
        expect(text).not_to include("%{")
      end

      it "pluralises with count" do
        text = backend.translate(locale.to_sym, "datetime.distance_in_words.x_days", count: 3)
        expect(text).to include("3")
        expect(text).not_to include("%{")
      end
    end
  end
end
