# frozen_string_literal: true

module Cct
  module Seed
    module Builders
      # Fictional comments (and replies) on a commentable resource, upserted by author + English
      # body. Pattern: decidim-comments/app/models/decidim/comments/seed.rb (v0.32.2).
      class Comments < Base
        def initialize(ctx, commentable:, entries:, after:, name: "")
          super(ctx)
          @commentable = commentable
          @entries = Array(entries)
          @after = after
          @name = name
        end

        def call
          return if @entries.empty?

          @entries.each_with_index do |entry, index|
            comment = save_comment(entry, parent: @commentable, at: @after + (index + 1).days, label: "#{@name}.comments.#{index}")
            next unless comment

            Array(entry["replies"]).each_with_index do |reply, position|
              save_comment(reply, parent: comment, at: @after + (index + 1).days + (position + 2).hours,
                                  label: "#{@name}.comments.#{index}.replies.#{position}")
            end
          end
          @commentable.update_comments_count if @commentable.respond_to?(:update_comments_count)
        end

        private

        def save_comment(entry, parent:, at:, label:)
          author = ctx.users[entry["author"]]
          return warn("#{label}: author #{entry["author"]} unavailable, skipped") unless author

          body = data.complete(entry["body"], "#{label}.body")
          scope = Decidim::Comments::Comment.where(root_commentable: @commentable, author:)
          comment = find_by_english(scope, "body", body["en"])
          return comment if comment

          at = [at, 1.minute.ago].min
          comment = Decidim::Comments::Comment.create!(
            commentable: parent,
            root_commentable: @commentable,
            author:,
            body:,
            created_at: at,
            updated_at: at
          )
          Decidim::ActionLogger.log("create", author, comment, nil, visibility: "public-only")
          parent.update_comments_count if parent.is_a?(Decidim::Comments::Comment) && parent.respond_to?(:update_comments_count)
          count(:comments)
          comment
        end
      end
    end
  end
end
