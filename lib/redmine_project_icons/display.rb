# frozen_string_literal: true

module RedmineProjectIcons
  # Wo Icons erscheinen. Jede Stelle lässt sich in den Plugin-Einstellungen
  # abschalten; zugeordnet wird über die aufgerufene Seite.
  module Display
    LOCATIONS = %w[project_list issue_lists header planning].freeze

    PAGES = {
      'project_list' => [%w[projects index]],
      'issue_lists' => [%w[issues index], %w[my page], %w[timelog index], %w[versions index], %w[versions show]],
      'planning' => [%w[calendars show], %w[gantts show]]
    }.freeze

    # Größe in px je Stelle (Projektliste: Hauptprojekt größer)
    SIZES = { 'project_list_root' => 28, 'project_list_child' => 20, 'issue_lists' => 16, 'planning' => 16,
              'header' => 28 }.freeze

    module_function

    def enabled?(location)
      settings = Setting.plugin_redmine_project_icons
      settings = settings.to_h.stringify_keys if settings.respond_to?(:to_h)
      settings.is_a?(Hash) && settings["show_in_#{location}"].to_s == '1'
    end

    def location_for(controller)
      return nil unless controller

      page = [controller.controller_name, controller.action_name]
      PAGES.find { |_location, pages| pages.include?(page) }&.first
    end

    # Unterprojekt in der Projektliste (Redmine setzt am Link die Klasse child)
    def project_list_child?(controller, html_options)
      return false unless location_for(controller) == 'project_list'

      classes = html_options.is_a?(Hash) ? html_options[:class].to_s : ''
      !classes.split.include?('root')
    end

    # Größe für einen Projektlink auf der aktuellen Seite oder nil (kein Icon)
    def link_size(controller, html_options)
      location = location_for(controller)
      return nil unless location && enabled?(location)

      if location == 'project_list'
        classes = html_options.is_a?(Hash) ? html_options[:class].to_s : ''
        classes.split.include?('root') ? SIZES['project_list_root'] : SIZES['project_list_child']
      else
        SIZES[location]
      end
    end
  end
end
