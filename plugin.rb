# frozen_string_literal: true

# name: group-based-titles
# about: Assigns user titles based on their primary group and trust level.
# version: 1.0.0
# authors: Your Name

enabled_site_setting :group_based_titles_enabled

module ::GroupBasedTitles
  PLUGIN_NAME = "group-based-titles".freeze

  class TitleManager
    def self.update_user_title(user)
      return if user.blank? || !SiteSetting.group_based_titles_enabled

      primary_group = user.primary_group
      return if primary_group.blank?

      trust_level = user.trust_level
      rules = SiteSetting.group_based_titles_rules
      return if rules.blank?

      matching_rule = rules.find do |rule|
        rule.split("|").first.strip.casecmp(primary_group.name.strip).zero?
      end
      return if matching_rule.blank?

      parts = matching_rule.split("|").map(&:strip)
      return if parts.length < 2

      new_title =
        case trust_level
        when 1 then parts[1]
        when 2 then parts[2]
        when 3 then parts[3]
        when 4 then parts[4]
        else nil
        end

      if new_title.present? && user.title != new_title
        user.update!(title: new_title)
        Rails.logger.info("GroupBasedTitles: Updated title for user #{user.username} to '#{new_title}'")
      end
    end
  end
end

after_initialize do
  on(:user_promoted) do |data|
    user = User.find_by(id: data[:user_id])
    ::GroupBasedTitles::TitleManager.update_user_title(user) if user
  end

  on(:user_updated) do |user|
    if user.saved_change_to_primary_group_id?
      ::GroupBasedTitles::TitleManager.update_user_title(user)
    end
  end

  on(:group_user_created) do |group_user|
    user = group_user.user
    if user&.primary_group_id == group_user.group_id
      ::GroupBasedTitles::TitleManager.update_user_title(user)
    end
  end
end
