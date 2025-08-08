# Group-Based Titles Plugin

This plugin for Discourse automatically assigns titles to users based on their primary group and trust level.

## Configuration

1.  Enable the plugin in your site settings (`add_title_based_on_trust_level_enabled`).
2.  Go to `Admin -> Settings -> Plugins` and find the "Group & Trust Level Titles" settings.
3.  In the `group_based_title_rules` setting, add rules for each group. The format for each rule is:
    ```
    group_name|tl1_title|tl2_title|tl3_title|tl4_title
    ```

### Example

To set titles for "Designers" and "Developers" groups, you would add two entries to the `group_based_title_rules` setting:
