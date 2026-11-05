# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Creates a group in the current organization (logged in the admin log).
      class CreateGroup < Decidim::Command
        def initialize(form)
          @form = form
        end

        def call
          return broadcast(:invalid) if form.invalid?

          group = Decidim.traceability.create!(
            Group,
            form.current_user,
            { organization: form.current_organization, slug: form.slug, name: form.name, description: form.description },
            visibility: "admin-only"
          )
          broadcast(:ok, group)
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          form.errors.add(:slug, :taken)
          broadcast(:invalid)
        end

        private

        attr_reader :form
      end
    end
  end
end
