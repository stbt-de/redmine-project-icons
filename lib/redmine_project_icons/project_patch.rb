# frozen_string_literal: true

module RedmineProjectIcons
  # Icon gehört zum Projekt und verschwindet mit ihm (samt Datei)
  module ProjectPatch
    def self.included(base)
      base.has_one :project_icon, dependent: :destroy
    end
  end
end
