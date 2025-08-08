# frozen_string_literal: true

# name: group-based-titles
# about: Assigns user titles based on their primary group and trust level.
# version: 2.1.0
# authors: Your Name

# This directive is crucial. It tells Discourse that the entire plugin's functionality
# is controlled by the 'group_based_titles_enabled' site setting.
# Discourse uses this to link the plugin to its settings.
enabled_site_setting :group_based_titles_enabled

module ::GroupBasedTitles
  PLUGIN_NAME = "group-based-titles".freeze

  class TitleManager
    def self.update_user_title(user)
      # Early exit if user is blank or the plugin is disabled in settings.
      return if user.blank? || !SiteSetting.group_based_titles_enabled

      primary_group = user.primary_group
      # Early exit if the user has no primary group.
      return if primary_group.blank?

      trust_level = user.trust_level
      rules = SiteSetting.group_based_titles_rules
      # Early exit if no rules are defined in the settings.
      return if rules.blank?

      # Find the rule that matches the user's primary group name (case-insensitive).
      matching_rule = rules.find do |rule|
        rule.split("|").first.strip.casecmp(primary_group.name.strip).zero?
      end
      # Early exit if no matching rule is found for this group.
      return if matching_rule.blank?

      parts = matching_rule.split("|").map(&:strip)
      # A valid rule must have at least the group name and one title.
      return if parts.length < 2

      # Select the new title based on the user's trust level.
      new_title =
        case trust_level
        when 1 then parts[1]
        when 2 then parts[2]
        when 3 then parts[3]
        when 4 then parts[4]
        else nil # No title for TL0 or other levels.
        end

      # Update the user's title only if the new title is not blank and is different
      # from the current one. This avoids unnecessary database writes.
      if new_title.present? && user.title != new_title
        user.update!(title: new_title)
        Rails.logger.info("GroupBasedTitles: Updated title for user #{user.username} to '#{new_title}'")
      end
    end
  end
end

after_initialize do
  # This event triggers when a user's trust level is promoted.
  on(:user_promoted) do |data|
    user = User.find_by(id: data[:user_id])
    ::GroupBasedTitles::TitleManager.update_user_title(user) if user
  end

  # This event triggers whenever a user record is updated.
  on(:user_updated) do |user|
    # We specifically check if the 'primary_group_id' was the field that changed.
    # This is the most efficient way to catch primary group changes.
    if user.saved_change_to_primary_group_id?
      ::GroupBasedTitles::TitleManager.update_user_title(user)
    end
  end

  # This event triggers when a user is added to a group.
  on(:group_user_created) do |group_user|
    user = group_user.user
    # We check if the group they were just added to is their primary group.
    # This handles the case where a primary group is assigned for the first time.
    if user&.primary_group_id == group_user.group_id
      ::GroupBasedTitles::TitleManager.update_user_title(user)
    end
  end
end
