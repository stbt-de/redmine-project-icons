# frozen_string_literal: true

module RedmineProjectIcons
  # Kopf jeder Seite: Grundgestaltung der Icons und – wenn der Kopf Icons
  # zeigen soll – die Daten für die Projektauswahl ("Zu einem Projekt
  # springen"), die project_icons.js dort einsetzt:
  #   <script type="application/json" id="project-icons-data">
  #     {"current": "/projects/website", "projects": {"/projects/website": {...}}}
  # Nur Projekte mit (geerbtem) Icon oder Farbe, nur sichtbare.
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context = {})
      tags = [stylesheet_link_tag('project_icons', plugin: 'redmine_project_icons')]
      return safe_join(tags, "\n") unless Resolver.entries.any?

      if Display.enabled?('header')
        tags << content_tag(:script, jump_data(context[:controller]).to_json.html_safe,
                            type: 'application/json', id: 'project-icons-data')
        tags << current_project_meta(context[:controller])
      end
      # Projektauswahl und Kalender (siehe project_icons.js)
      tags << javascript_include_tag('project_icons', plugin: 'redmine_project_icons', defer: true)

      safe_join(tags, "\n")
    end

    private

    # Icon des aktuellen Projekts für Themes, die das Logo selbst darstellen
    # (data-branding-logo="theme", z. B. Klar): sie zeigen es an der Stelle
    # des Logos.
    #   <meta name="project-icon" content="/projects/x/icon?v=…" data-color="#…" data-letter="X">
    # content ist leer, wenn nur eine Farbe gilt (Kachel mit Anfangsbuchstabe).
    def current_project_meta(controller)
      project = controller.instance_variable_get(:@project)
      return nil unless project.is_a?(Project) && project.persisted?

      effective = Resolver.effective(project)
      return nil unless effective

      url = effective.icon? ? controller.project_icon_path(project, v: effective.digest) : ''
      tag.meta(name: 'project-icon', content: url,
               data: { color: effective.color, letter: project.name.to_s.strip[0].to_s.upcase })
    end

    def jump_data(controller)
      projects = {}
      decorated_projects.each do |project|
        effective = Resolver.effective(project)
        next unless effective

        path = controller.project_path(project)
        projects[path] = {
          icon: (effective.icon? ? controller.project_icon_path(project, v: effective.digest) : nil),
          color: effective.color,
          letter: project.name.to_s.strip[0].to_s.upcase
        }
      end

      current = controller.instance_variable_get(:@project)
      { current: (current&.persisted? ? controller.project_path(current) : nil), projects: projects }
    end

    # Sichtbare Projekte in den Teilbäumen der Projekte mit Icon oder Farbe
    def decorated_projects
      conditions = Resolver.entries.map { |entry| "(#{Project.table_name}.lft >= #{entry.lft.to_i} AND #{Project.table_name}.rgt <= #{entry.rgt.to_i})" }
      return Project.none if conditions.empty?

      Project.visible.where(conditions.join(' OR ')).select(:id, :identifier, :name, :lft, :rgt, :status)
    end
  end
end
