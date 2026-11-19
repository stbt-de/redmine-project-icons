# frozen_string_literal: true

module RedmineProjectIcons
  # Projekteinstellungen: Reiter "Darstellung" (Icon und Farbe) für alle, die
  # das Projekt bearbeiten dürfen
  module ProjectsHelperPatch
    def project_settings_tabs
      tabs = super
      if User.current.allowed_to?(:edit_project, @project)
        tabs << { name: 'project_icon', action: :edit_project,
                  partial: 'project_icons/settings', label: :label_project_icons_tab }
      end
      tabs
    end
  end
end
