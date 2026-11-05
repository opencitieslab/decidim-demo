# frozen_string_literal: true

module Cct
  module Seed
    # Deletes the fictional layer only: seed-marked users and what they authored, plus the
    # fictional "Demo idea" budget projects. Anything created by real people (including comments
    # they left on fictional proposals, which go with those proposals) and all real-data records
    # stay. Run `cct:seed` again to restore the demo content.
    class Reset
      def initialize(content_path:, host:, logger:)
        @content_path = content_path
        @host = host
        @logger = logger
      end

      def call
        organization = Seed.find_organization(@host)
        content = YAML.safe_load_file(@content_path, aliases: false)
        stats = Hash.new(0)

        ActiveRecord::Base.transaction do
          users = Seed.fictional_users(organization).to_a
          user_ids = users.map(&:id)
          proposals = Builders::Proposals.fictional_scope(organization).to_a

          # Comments on fictional proposals (any author) and comments by fictional users elsewhere.
          comments = Decidim::Comments::Comment.where(root_commentable: proposals)
                                               .or(Decidim::Comments::Comment.where(decidim_author_id: user_ids, decidim_author_type: "Decidim::UserBaseEntity"))
                                               .to_a
          roots = comments.map(&:root_commentable).uniq - proposals
          stats[:comments] = destroy_logged(comments)
          roots.each { |root| root.update_comments_count if root.respond_to?(:update_comments_count) }

          stats[:proposals] = destroy_logged(proposals)
          stats[:supports] = destroy_all(Decidim::Proposals::ProposalVote.where(decidim_author_id: user_ids))
          stats[:budget_orders] = destroy_all(Decidim::Budgets::Order.where(decidim_user_id: user_ids))
          stats[:meeting_registrations] = destroy_all(Decidim::Meetings::Registration.where(decidim_user_id: user_ids))
          stats[:projects] = destroy_logged(fictional_projects(organization, content))

          stats[:groups] = destroy_groups(organization, users)

          Decidim::ActionLog.where(user_id: user_ids).delete_all
          users.each(&:destroy!)
          stats[:users] = users.size
        end

        @logger.info("[cct:seed] reset_demo_content for #{organization.host}: " + stats.map { |k, v| "#{k}=#{v}" }.join(", "))
        stats
      end

      private

      def fictional_projects(organization, content)
        process = Decidim::ParticipatoryProcess.find_by(organization:, slug: Builders::WardAllocations::SLUG)
        return [] unless process

        budgets = Decidim::Budgets::Budget.where(component: process.components.where(manifest_name: "budgets"))
        titles = Builders::WardAllocations.fictional_titles(content)
        Decidim::Budgets::Project.where(budget: budgets).where("title ->> 'en' IN (?)", titles).to_a
      end

      def destroy_logged(records)
        records.each do |record|
          Decidim::ActionLog.where(resource_type: record.class.name, resource_id: record.id).delete_all
          record.destroy!
        end
        records.size
      end

      def destroy_all(scope) = scope.destroy_all.size

      # Seeded demo groups (their real members, if an admin added any, lose the group's access),
      # then the fictional users' remaining group authorizations.
      def destroy_groups(organization, users)
        return 0 unless defined?(Cct::Groups::Group) && Cct::Groups::Group.table_exists?

        groups = Cct::Groups.for(organization).seeded.to_a
        groups.each do |group|
          Decidim::ActionLog.where(resource_type: group.class.name, resource_id: group.id).delete_all
          Cct::Groups.destroy_group!(group)
        end
        users.each { |user| Cct::Groups.remove_user!(user) }
        groups.size
      end
    end
  end
end
