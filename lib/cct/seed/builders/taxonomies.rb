# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # Decidim 0.32 taxonomies (they replace scopes and categories):
      # - Area: 20 subcouncils -> their wards (2021 delimitation + wards 117/118 from the 2026 layer,
      #   flagged in their names because the subcouncil is inferred);
      # - Theme: IDP 2022-27 priorities (-> objectives) and foundations;
      # - Directorate: the directorates the real items belong to.
      # One taxonomy filter per root, available to processes and used by the components.
      class Taxonomies < Base
        SUBCOUNCIL = /\ASubcouncil (\d+)\b/
        WARD = /\AWard (\d+)\b/

        def call
          ctx.store[:taxonomies] = { subcouncil: {}, ward: {}, theme: {}, directorate: {}, filters: {} }
          areas!
          themes!
          directorates!
          log "taxonomies: #{store[:subcouncil].size} subcouncils, #{store[:ward].size} wards, " \
              "#{store[:theme].size} themes, #{store[:directorate].size} directorates"
        end

        private

        def store = ctx.store[:taxonomies]

        def areas!
          root = upsert_root(t(:taxonomies, :area_root))
          existing = root.all_children.to_a

          data.subcouncils.sort_by { |s| s["number"] }.each do |subcouncil|
            number = subcouncil["number"]
            record = existing.find { |tx| tx.name["en"].to_s[SUBCOUNCIL, 1].to_i == number }
            store[:subcouncil][number] = save_taxonomy(record, parent: root, weight: number,
                                                               name: fmt(t(:taxonomies, :subcouncil), number:))
          end

          data.wards.sort_by { |w| w["number"] }.each do |ward|
            number = ward["number"]
            record = existing.find { |tx| tx.name["en"].to_s[WARD, 1].to_i == number }
            store[:ward][number] = save_taxonomy(record, parent: store[:subcouncil].fetch(ward["subcouncil"]), weight: number,
                                                         name: ward_name(ward))
          end

          filter!(:area, root)
        end

        def ward_name(ward)
          name = fmt(t(:taxonomies, :ward), number: ward["number"])
          return name unless ward["delimitation"].to_s.start_with?("2026")

          suffix = ward["delimitation"].to_s.include?("UNVERIFIED") ? :ward_unverified_suffix : :ward_inferred_suffix
          name.to_h { |locale, text| [locale, text + t(:taxonomies, suffix)[locale]] }
        end

        def themes!
          root = upsert_root(t(:taxonomies, :theme_root))
          existing = root.all_children.to_a

          data.themes.each_with_index do |theme, index|
            content = data.content.dig("themes", theme["key"]).to_h
            name = data.complete(content.fetch("name", {}).merge("en" => theme["name"]), "themes.#{theme["key"]}")
            record = existing.find { |tx| tx.parent_id == root.id && tx.name["en"] == theme["name"] }
            parent = store[:theme][theme["key"]] = save_taxonomy(record, parent: root, weight: index, name:)

            objectives = Array(theme["objectives"])
            # Foundations have a single objective that repeats their own name: no sub-level.
            next if objectives.size == 1 && objectives.first.sub(/\A\d+\.\s*/, "") == theme["name"]

            objectives.each_with_index do |objective, position|
              translated = Array(content["objectives"])[position].to_h
              objective_name = data.complete(translated.merge("en" => objective), "themes.#{theme["key"]}.objectives.#{position}")
              record = existing.find { |tx| tx.parent_id == parent.id && tx.name["en"] == objective }
              save_taxonomy(record, parent:, weight: position, name: objective_name)
            end
          end

          filter!(:theme, root)
        end

        def directorates!
          root = upsert_root(t(:taxonomies, :directorate_root))
          existing = root.all_children.to_a
          used = data.items.map(&:directorate_key).compact.uniq

          used.each_with_index do |key, index|
            name = t(:directorates, key)
            record = existing.find { |tx| tx.name["en"] == name["en"] }
            store[:directorate][key] = save_taxonomy(record, parent: root, weight: index, name:)
          end

          filter!(:directorate, root)
        end

        def upsert_root(name)
          root = organization.taxonomies.roots.find_by("name ->> 'en' = ?", name["en"])
          root ||= Decidim::Taxonomy.new(organization:, parent: nil)
          root.name = name
          root.save! if root.changed?
          root
        end

        def save_taxonomy(record, parent:, weight:, name:)
          record ||= Decidim::Taxonomy.new(organization:)
          created = record.new_record?
          record.parent = parent
          record.weight = weight
          record.name = name
          record.save! if record.changed?
          count(:taxonomies) if created
          record
        end

        # One filter per root taxonomy covering all its items, offered to processes and set on the
        # seeded components.
        def filter!(kind, root)
          manifests = ["participatory_processes"]
          filter = Decidim::TaxonomyFilter.where(root_taxonomy: root).find { |f| f.participatory_space_manifests == manifests }
          filter ||= Decidim::TaxonomyFilter.create!(root_taxonomy: root, participatory_space_manifests: manifests)

          wanted = Decidim::Taxonomy.non_roots.part_of(root.id).pluck(:id)
          current = filter.filter_items.pluck(:taxonomy_item_id)
          (wanted - current).each { |id| filter.filter_items.create!(taxonomy_item_id: id) }
          filter.filter_items.where(taxonomy_item_id: current - wanted).destroy_all
          store[:filters][kind] = filter
        end
      end
    end
  end
end
