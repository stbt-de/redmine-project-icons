# frozen_string_literal: true

module RedmineProjectIcons
  # Wird ApplicationHelper vorangestellt (init.rb). Setzt das Projekt-Icon
  # dort ein, wo Redmine Projekte zeigt:
  #   link_to_project      Projektliste, Ticketlisten (Spalte Projekt),
  #                        Gantt – je nach Seite und Einstellung
  #   page_header_title    Kopf: Icon vor dem Projekttitel
  #   link_to_issue        Kalender: Icon vor Tickets mit Projektangabe
  module ApplicationHelperPatch
    # only_own: nur ein eigenes Icon bzw. eine eigene Farbe zeigen, kein
    # geerbtes (Unterprojekte in der Projektliste)
    def project_icon_tag(project, size: 16, only_own: false)
      effective = Resolver.effective(project)
      return ''.html_safe unless effective
      return ''.html_safe if only_own && !effective.own?(project)

      style = ["--project-icon-size: #{size.to_i}px"]
      style << "--project-color: #{effective.color}" if effective.color
      classes = ['project-icon', ("project-icon-#{size.to_i}")]

      if effective.icon?
        image_tag(project_icon_path(project, v: effective.digest),
                  alt: '', width: size, height: size, loading: 'lazy',
                  class: (classes + ['project-icon-image']).join(' '), style: style.join('; '))
      else
        content_tag(:span, project.name.to_s.strip[0].to_s.upcase,
                    class: (classes + ['project-icon-tile']).join(' '), style: style.join('; '),
                    'aria-hidden': 'true')
      end
    end

    def link_to_project(project, options = {}, html_options = nil)
      size = @project_icons_in_header ? nil : Display.link_size(controller, html_options)
      return super unless size && project.is_a?(Project) && !project.archived?

      # Projektliste: Unterprojekte stehen unter ihrem Hauptprojekt – ein
      # geerbtes Icon wäre dort nur eine Wiederholung
      icon = project_icon_tag(project, size: size, only_own: Display.project_list_child?(controller, html_options))
      return super if icon.blank?

      link_to(icon + h(project.name),
              project_url(project, { only_path: true }.merge(options)),
              html_options)
    end

    def page_header_title
      # Brotkrumen im Kopf bekommen kein eigenes Icon
      @project_icons_in_header = true
      title = super
      @project_icons_in_header = false
      return title unless @project&.persisted? && Display.enabled?('header')

      icon = project_icon_tag(@project, size: Display::SIZES['header'])
      icon.blank? ? title : (icon + title)
    end

    # Kalender: jedes Ticket mit Icon (zeigt sonst kein Projekt);
    # übrige Planungsseiten: nur wo Redmine das Projekt nennt
    def link_to_issue(issue, options = {})
      link = super
      in_calendar = controller&.controller_name == 'calendars'
      return link unless (options[:project] || in_calendar) && issue.respond_to?(:project) &&
                         Display.location_for(controller) == 'planning' && Display.enabled?('planning')

      icon = project_icon_tag(issue.project, size: Display::SIZES['planning'])
      icon.blank? ? link : (icon + link)
    end
  end
end
