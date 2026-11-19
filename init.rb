# frozen_string_literal: true

# Project Icons – Icon und Farbe für Projekte
#
# Je Projekt ein Icon und eine Farbe (Projekteinstellungen → Darstellung).
# Unterprojekte erben beides vom nächsten Elternprojekt, solange sie kein
# eigenes haben. Ohne Icon erscheint eine Kachel mit dem Anfangsbuchstaben
# in der Projektfarbe.
#
# Wo Icons erscheinen, legt der Admin fest (Administration → Plugins →
# Project Icons → Konfigurieren): Projektliste, Ticketlisten, Kopf und
# Projektauswahl, Kalender und Gantt.

Redmine::Plugin.register :redmine_project_icons do
  name 'Project Icons'
  author 'stbt.de'
  author_url 'https://stbt.de/'
  description 'Icon und Farbe je Projekt, vererbt an Unterprojekte – in Projektliste, Ticketlisten, Kopf, Kalender und Gantt.'
  version '1.0.0'
  url 'https://github.com/stbt-de/redmine-project-icons'
  requires_redmine version_or_higher: '6.0.0'

  settings default: {
    'show_in_project_list' => '1',
    'show_in_issue_lists' => '1',
    'show_in_header' => '1',
    'show_in_planning' => '1'
  }, partial: 'settings/project_icons'
end

# Hook-Klasse laden (Zeitwerk lädt lib/ nur bei Bedarf) und Redmine an den
# Stellen erweitern, an denen Projekte erscheinen
RedmineProjectIcons::Hooks
ApplicationHelper.prepend(RedmineProjectIcons::ApplicationHelperPatch) unless ApplicationHelper < RedmineProjectIcons::ApplicationHelperPatch
ProjectsHelper.prepend(RedmineProjectIcons::ProjectsHelperPatch) unless ProjectsHelper < RedmineProjectIcons::ProjectsHelperPatch
Project.include(RedmineProjectIcons::ProjectPatch) unless Project < RedmineProjectIcons::ProjectPatch
