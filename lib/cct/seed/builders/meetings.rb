# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # In-person meetings at real subcouncil offices (addresses from the City's 2025/26 venues
      # list). Dates are illustrative and labelled as such. No geocoding call is made.
      # Pattern: decidim-meetings/lib/decidim/meetings/seeds.rb (v0.32.2).
      class Meetings < Base
        RECESS = (Date.new(2026, 12, 8)..Date.new(2027, 1, 14))
        CIVIC_CENTRE = "Civic Centre Concourse, Hertzog Boulevard, Cape Town"

        # `count` dates spread evenly between `from` and `to` on the given weekdays, outside the
        # December-January recess.
        def self.spread_dates(count, from:, to:, wdays: [2, 3, 4])
          candidates = (from..to).select { |day| wdays.include?(day.wday) && !RECESS.cover?(day) }
          return candidates.first(count) if candidates.size <= count

          Array.new(count) { |index| candidates[(index * candidates.size) / count] }
        end

        # rubocop:disable Metrics/ParameterLists
        def subcouncil_meeting!(component:, number:, date:, kind:, taxonomies: [], registrations: false)
          subcouncil = data.subcouncil(number)
          address = subcouncil.fetch("office_address")
          unverified = address.include?("verify")
          title = fmt(t(:meetings, :"#{kind}_title"), number:)
          start = ctx.time_on(date, kind == :idp ? 18 : 10)
          upsert!(
            component:,
            title:,
            description: t(:meetings, :"#{kind}_description"),
            location: fmt(t(:meetings, :location), number:),
            hints: t(:meetings, unverified ? :venue_unverified_hint : :venue_hint),
            address: address.sub(/\s*\((?:as published[^)]*)\)\s*\z/, ""),
            start:,
            finish: start + 2.hours,
            registrations:,
            taxonomies: [ctx.taxonomy(:subcouncil, number), *taxonomies]
          )
        end
        # rubocop:enable Metrics/ParameterLists

        def civic_centre_meeting!(component:, date:, taxonomies: [])
          start = ctx.time_on(date, 18)
          upsert!(
            component:,
            title: t(:meetings, :budget_session_title),
            description: t(:meetings, :budget_session_description),
            location: t(:meetings, :civic_centre_location),
            hints: t(:meetings, :venue_hint),
            address: CIVIC_CENTRE,
            start:,
            finish: start + 2.hours,
            registrations: true,
            taxonomies:
          )
        end

        private

        # rubocop:disable Metrics/ParameterLists
        def upsert!(component:, title:, description:, location:, hints:, address:, start:, finish:, registrations:, taxonomies:)
          meeting = find_by_english(Decidim::Meetings::Meeting.where(component:), "title", title["en"])
          created = meeting.nil?
          meeting ||= Decidim::Meetings::Meeting.new(component:, author: organization)
          note = t(:meetings, :illustrative_note)
          meeting.assign_attributes(
            title:,
            description: description.to_h { |locale, text| [locale, Html.paragraph(text) + "<p><em>#{Html.escape(note[locale])}</em></p>"] },
            location:,
            location_hints: hints,
            address:,
            start_time: start,
            end_time: finish,
            type_of_meeting: :in_person,
            registration_type: registrations ? :on_this_platform : :registration_disabled,
            registrations_enabled: registrations,
            available_slots: registrations ? 80 : 0,
            registration_terms: html(t(:meetings, :registration_terms)),
            iframe_embed_type: :none,
            iframe_access_level: :all,
            private_meeting: false,
            transparent: true,
            comments_enabled: true
          )
          meeting.published_at ||= Time.current
          meeting.save!
          set_taxonomies(meeting, taxonomies)
          count(:meetings) if created
          meeting
        end
        # rubocop:enable Metrics/ParameterLists
      end
    end
  end
end
