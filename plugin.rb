# frozen_string_literal: true

# name: group-based-titles
# about: Assigns user titles based on their primary group and trust level.
# version: 2.0.0
# authors: Your Name
# url: TODO

enabled_site_setting :add_title_based_on_trust_level_enabled

module ::GroupBasedTitles
  PLUGIN_NAME = "group-based-titles"

  class TitleManager
    def self.update_user_title(user)
      # 确保用户对象存在
      return if user.blank?

      # 获取用户的主要用户组和信任级别
      primary_group = user.primary_group
      trust_level = user.trust_level

      # 如果没有主要用户组，则不进行任何操作
      return if primary_group.blank?

      # 解析设置中的规则
      rules = SiteSetting.group_based_title_rules.split("\n").map(&:strip).reject(&:blank?)
      
      # 查找与用户当前主要用户组匹配的规则
      # 规则格式: group_name|tl1_title|tl2_title|tl3_title|tl4_title
      matching_rule = rules.find do |rule|
        rule.split("|").first.strip.casecmp(primary_group.name.strip) == 0
      end

      # 如果没有找到匹配的规则，则不进行任何操作
      return if matching_rule.blank?

      parts = matching_rule.split("|").map(&:strip)
      # 期望格式: [group_name, tl1_title, tl2_title, tl3_title, tl4_title]
      # 至少需要 group_name 和一个头衔
      return if parts.length < 2

      # 根据信任级别选择头衔
      # parts[0] 是用户组名
      # parts[1] 是 TL1 头衔
      # parts[2] 是 TL2 头衔, etc.
      new_title =
        case trust_level
        when 1
          parts[1]
        when 2
          parts[2]
        when 3
          parts[3]
        when 4
          parts[4]
        else
          # 对于 TL0 或其他级别，我们不设置头衔，或者可以设置为空
          nil
        end

      # 只有当新头衔有效且与当前头衔不同时才更新
      # new_title.present? 确保我们不会将头衔设置为空字符串 ""
      if new_title.present? && user.title != new_title
        user.update!(title: new_title)
        Rails.logger.info("GroupBasedTitles: Updated title for user #{user.username} to '#{new_title}'")
      end
    end
  end
end

after_initialize do
  # 事件：当用户信任级别提升时
  on(:user_promoted) do |data|
    user = User.find_by(id: data[:user_id])
    ::GroupBasedTitles::TitleManager.update_user_title(user) if user
  end

  # 事件：当用户信息更新时（用于捕捉主要用户组的变化）
  on(:user_updated) do |user|
    # `saved_change_to_primary_group_id?` 是一个高效的检查，只在主要用户组ID实际变化时触发
    if user.saved_change_to_primary_group_id?
      ::GroupBasedTitles::TitleManager.update_user_title(user)
    end
  end

  # 事件：当用户被添加到用户组时
  # 这有助于处理用户首次被设置主要用户组的情况
  on(:group_user_created) do |group_user|
    user = group_user.user
    # 仅当被添加的用户组是该用户的主要用户组时才更新
    if user&.primary_group_id == group_user.group_id
      ::GroupBasedTitles::TitleManager.update_user_title(user)
    end
  end
end
