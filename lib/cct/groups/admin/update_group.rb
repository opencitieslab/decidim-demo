# frozen_string_literal: true

module Cct
  module Groups
    module Admin
      # Updates a group's name and description (the slug never changes; logged in the admin log).
      class UpdateGroup < Decidim::Command
        def initialize(form, group)
          @form = form
          @group = group
        end

        def call
          return broadcast(:invalid) if form.invalid?

          Decidim.traceability.update!(group, form.current_user, { name: form.name, description: form.description },
                                       visibility: "admin-only")
          broadcast(:ok, group)
        end

        private

        attr_reader :form, :group
      end
    end
  end
end
