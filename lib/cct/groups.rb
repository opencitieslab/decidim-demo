# frozen_string_literal: true

module Cct
  # Admin-managed participant groups (plan U5, KTD4, tender p13 D2/D4).
  #
  # Admins create groups and add or remove members under Admin > Participants > Groups. Group
  # membership is turned into Decidim's own permission system through the `cct_group_membership`
  # authorization: one granted authorization per user whose metadata lists the slugs of their
  # groups ({ "groups" => [sorted slugs] }). Admins then restrict any component or resource action
  # to some groups with the `allowed_groups` option in the Permissions UI
  # (Cct::Authorizations::GroupActionAuthorizer). The authorization is never self-service: it is
  # rewritten from the memberships by every membership change and group deletion (`sync!`), and
  # removed when the user belongs to no group.
  #
  # Everything is organization-scoped: groups belong to one organization, members must be users of
  # that organization, and the authorization only ever lists groups of the user's organization.
  module Groups
    WORKFLOW = "cct_group_membership"

    module_function

    # The organization's groups.
    def for(organization) = Group.where(organization:)

    # Sorted slugs of the groups the user belongs to (only groups of the user's organization).
    def slugs_for(user)
      Group.where(organization: user.organization)
           .joins(:memberships)
           .where(cct_group_memberships: { decidim_user_id: user.id })
           .distinct
           .pluck(:slug)
           .sort
    end

    # Plain-text name of a translatable hash (a group's name or description) in the current locale,
    # falling back to English, then to any value. Escape it when rendering.
    def translate(value, locale = I18n.locale)
      value = value.to_h.stringify_keys
      value[locale.to_s].presence || value["en"].presence || value.values.compact_blank.first.to_s
    end

    def name_for(group) = translate(group.name).presence || group.slug

    # A user of this organization who can be added to a group, found by email (case-insensitive),
    # or nil. Deleted and managed (impersonated, email-less) accounts are excluded.
    def find_member_candidate(organization, email)
      email = email.to_s.strip.downcase
      return if email.blank? || !email.match?(Devise.email_regexp)

      Decidim::User.where(organization:, managed: false, deleted_at: nil).find_by("LOWER(email) = ?", email)
    end

    def authorization_for(user)
      Decidim::Authorization.find_by(user:, name: WORKFLOW)
    end

    # Creates, updates or removes the user's group authorization so it matches their memberships.
    # Idempotent.
    def sync!(user)
      return revoke!(user) if user.nil? || user.deleted?

      slugs = slugs_for(user)
      return revoke!(user) if slugs.empty?

      authorization = Decidim::Authorization.find_or_initialize_by(user:, name: WORKFLOW)
      return authorization if authorization.granted? && authorization.metadata.to_h["groups"] == slugs

      authorization.metadata = { "groups" => slugs }
      authorization.unique_id = nil
      authorization.grant!
      authorization
    end

    def revoke!(user)
      Decidim::Authorization.where(user:, name: WORKFLOW).destroy_all if user
      nil
    end

    # Adds the user to the group (no-op when already a member) and resyncs their authorization.
    # Returns true when a membership was created.
    def add_member!(group, user)
      raise ArgumentError, "user and group belong to different organizations" unless user.decidim_organization_id == group.decidim_organization_id
      raise ArgumentError, "deleted users cannot join a group" if user.deleted?

      created = false
      Membership.transaction(requires_new: true) do
        Membership.find_or_create_by!(group:, user:) { created = true }
      end
      sync!(user)
      created
    rescue ActiveRecord::RecordNotUnique
      sync!(user)
      false
    end

    # Removes the user from the group and resyncs their authorization. Returns true when a
    # membership was removed.
    def remove_member!(group, user)
      removed = Membership.where(group:, user:).delete_all.positive?
      sync!(user)
      removed
    end

    # Deletes the group and its memberships, then resyncs every former member. Pass a block to wrap
    # the deletion itself (e.g. in Decidim.traceability).
    def destroy_group!(group)
      users = group.users.to_a
      if block_given?
        yield
      else
        group.destroy!
      end
      users.each { |user| sync!(user) }
      users
    end

    # Resyncs every member of the group (after a change that affects their metadata).
    def sync_members!(group)
      group.users.find_each { |user| sync!(user) }
    end

    # Removes all of the user's memberships and their authorization (account deletion).
    def remove_user!(user)
      Membership.where(user:).delete_all
      revoke!(user)
    end
  end
end
