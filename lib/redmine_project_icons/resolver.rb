# frozen_string_literal: true

module RedmineProjectIcons
  # Je Anfrage einmal gelesen (wird von Rails nach jeder Anfrage geleert)
  class Current < ActiveSupport::CurrentAttributes
    attribute :entries
  end

  # Icon und Farbe, die für ein Projekt gelten – eigene oder geerbte.
  #
  # Redmine speichert den Projektbaum als Nested Set (lft/rgt): ein Projekt A
  # ist Vorfahr von B, wenn A.lft <= B.lft und A.rgt >= B.rgt. Die wenigen
  # Projekte mit Icon oder Farbe werden einmal je Anfrage geladen; für jedes
  # angezeigte Projekt gilt dann der nächste Vorfahr (größtes lft) – ohne eine
  # Abfrage pro Projekt.
  module Resolver
    Entry = Struct.new(:project_id, :lft, :rgt, :filename, :digest, :content_type, :color, keyword_init: true)

    # Was angezeigt wird: Bild (digest/content_type) und/oder Farbe
    Effective = Struct.new(:digest, :filename, :content_type, :color, :source_project_id, :color_project_id,
                           keyword_init: true) do
      def icon?
        filename.present?
      end

      # Eigenes Erscheinungsbild des Projekts statt eines geerbten: eigenes
      # Icon, oder – wenn nirgends ein Icon gilt – eigene Farbe (Kachel)
      def own?(project)
        icon? ? source_project_id == project.id : color_project_id == project.id
      end
    end

    module_function

    # Ohne Migration (Tabelle fehlt) zeigt das Plugin nichts an, statt jede
    # Seite mit einem Fehler abzubrechen. Gemerkt wird nur "vorhanden".
    def table_ready?
      @table_ready ||= ProjectIcon.table_exists?
    end

    def entries
      return [] unless table_ready?

      Current.entries ||= ProjectIcon.joins(:project)
                                     .where('project_icons.filename IS NOT NULL OR project_icons.color IS NOT NULL')
                                     .pluck('project_icons.project_id', 'projects.lft', 'projects.rgt',
                                            'project_icons.filename', 'project_icons.digest',
                                            'project_icons.content_type', 'project_icons.color')
                                     .map do |id, lft, rgt, filename, digest, content_type, color|
        Entry.new(project_id: id, lft: lft, rgt: rgt, filename: filename, digest: digest,
                  content_type: content_type, color: color)
      end
    end

    def reset!
      Current.entries = nil
      @table_ready = nil
    end

    def effective(project)
      return nil unless project.is_a?(Project) && project.lft && project.rgt

      candidates = entries.select { |entry| entry.lft <= project.lft && entry.rgt >= project.rgt }
      icon = candidates.select { |entry| entry.filename.present? }.max_by(&:lft)
      color = candidates.select { |entry| entry.color.present? }.max_by(&:lft)
      return nil unless icon || color

      Effective.new(digest: icon&.digest, filename: icon&.filename, content_type: icon&.content_type,
                    color: color&.color, source_project_id: icon&.project_id, color_project_id: color&.project_id)
    end
  end
end
