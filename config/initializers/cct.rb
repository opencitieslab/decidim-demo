# frozen_string_literal: true

# Home for the City of Cape Town (CCT) demo customisations: locale plumbing, the ward
# authorization workflow and the decorators of Decidim classes.

# Locales. The enabled set comes from DECIDIM_AVAILABLE_LOCALES (en,af,xh; see
# docker-compose.yml and deploy/env.production.example). Afrikaans and isiXhosa fall
# back to English for any key we have not translated, so a missing string never
# renders as "translation missing". This runs after Decidim's own
# `decidim_core.setup_i18n` initializer (which sets `fallbacks = true`) and before
# Rails applies the I18n config in `after_initialize`, so it takes effect.
Rails.application.config.i18n.fallbacks = [:en, { af: [:en], xh: [:en] }]

# Ward targeting (plan U4, KTD5). Registration and the account page store the participant's
# ward and grant this authorization automatically (Cct::WardResidency); there is no form to
# request it. Admins restrict actions with the `allowed_wards` option in the Permissions UI.
# The organization must list it in available_authorizations (`cct:seed` does that).
unless Decidim::Verifications.find_workflow_manifest(Cct::WardResidency::WORKFLOW)
  Decidim::Verifications.register_workflow(Cct::WardResidency::WORKFLOW) do |workflow|
    workflow.engine = Cct::WardResident::Engine
    workflow.action_authorizer = "Cct::Authorizations::WardActionAuthorizer"
    workflow.renewable = false
    workflow.icon = "map-pin-line"

    workflow.options do |options|
      options.attribute :allowed_wards, type: :string, required: false
    end
  end
  # The engine is defined while initializers run, after Rails registered engine route sets for
  # drawing (Engine's own :add_routing_paths initializer), so register its routes here.
  Rails.application.routes_reloader.route_sets << Cct::WardResident::Engine.routes
end

# Decorators (Decidim/Rails convention: prepend in to_prepare). lib/ is autoloaded once
# (config/application.rb), so these modules are never reloaded and each prepend is guarded.
Rails.application.config.to_prepare do
  {
    "Decidim::RegistrationForm" => Cct::Decorators::RegistrationFormDecorator,
    "Decidim::CreateRegistration" => Cct::Decorators::CreateRegistrationDecorator,
    "Decidim::AccountForm" => Cct::Decorators::AccountFormDecorator,
    "Decidim::UpdateAccount" => Cct::Decorators::UpdateAccountDecorator,
    "Decidim::DestroyAccount" => Cct::Decorators::DestroyAccountDecorator,
    "Decidim::DownloadYourDataSerializers::DownloadYourDataUserSerializer" => Cct::Decorators::DownloadYourDataUserSerializerDecorator,
    # Per-budget vote restrictions (the ward allocation budgets share one component).
    "Decidim::Budgets::Budget" => Cct::Decorators::BudgetDecorator,
    "Decidim::Budgets::Permissions" => Cct::Decorators::BudgetsPermissionsDecorator
  }.each do |class_name, decorator|
    klass = class_name.constantize
    klass.prepend(decorator) unless klass <= decorator
  end
end
