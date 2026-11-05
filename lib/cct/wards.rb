# frozen_string_literal: true

require "json"

module Cct
  # The 118 City of Cape Town wards and their subcouncils, read from the real-data seed file
  # (db/seeds/cct/cct-seed-sources.json). That file is the single source of truth for the
  # registration ward select, its validation and the ward authorization, so they work before
  # (and without) `cct:seed` having created the "Area" taxonomy.
  module Wards
    AREA_PLACES = 3

    Ward = Struct.new(:number, :subcouncil, :area, keyword_init: true)

    module_function

    def source_path = Rails.root.join("db/seeds/cct/cct-seed-sources.json")

    def all
      @all ||= load.freeze
    end

    def numbers = all.map(&:number)

    # The ward with this number, or nil. Accepts "23", 23 or " 23 ".
    def find(value)
      number = parse(value)
      number && all.find { |ward| ward.number == number }
    end

    def valid?(value) = find(value).present?

    # Integer ward number from user input, or nil when it is not a plain positive number.
    def parse(value)
      text = value.to_s.strip
      text.match?(/\A\d{1,4}\z/) ? text.to_i : nil
    end

    # "Ward 23 — Subcouncil 1 (Atlantis, Mamre, Melkbosstrand…)" in the current locale.
    def label(ward)
      I18n.t("cct.wards.option", number: ward.number, subcouncil: ward.subcouncil, area: ward.area)
    end

    # [[label, number], ...] for a select.
    def options = all.map { |ward| [label(ward), ward.number] }

    def load
      data = JSON.parse(File.read(source_path, encoding: "UTF-8"))
      areas = data.fetch("subcouncils").to_h { |s| [s.fetch("number"), short_area(s["area_description"])] }
      data.fetch("wards").map do |ward|
        Ward.new(number: ward.fetch("number"), subcouncil: ward.fetch("subcouncil"), area: areas[ward.fetch("subcouncil")])
      end.sort_by(&:number)
    end

    # First few place names of a subcouncil's area description, splitting on commas outside
    # parentheses: "Khayelitsha (Kuyasa, Harare), Makhaza, ..." -> "Khayelitsha (Kuyasa, Harare), Makhaza…".
    def short_area(description)
      parts = []
      depth = 0
      current = +""
      description.to_s.each_char do |char|
        depth += 1 if char == "("
        depth -= 1 if char == ")" && depth.positive?
        if char == "," && depth.zero?
          parts << current.strip
          current = +""
        else
          current << char
        end
      end
      parts << current.strip if current.strip.present?
      shown = parts.first(AREA_PLACES).join(", ")
      parts.size > AREA_PLACES ? "#{shown}…" : shown
    end
  end
end
