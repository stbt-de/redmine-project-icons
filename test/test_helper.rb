# frozen_string_literal: true

require File.expand_path('../../../test/test_helper', __dir__)

module RedmineProjectIcons
  module TestHelper
    FILES = File.expand_path('fixtures/files', __dir__)

    def icon_upload(name, type)
      Rack::Test::UploadedFile.new(File.join(FILES, name), type)
    end

    def reset_project_icons
      ProjectIcon.delete_all
      FileUtils.rm_rf(ProjectIcon.directory)
      RedmineProjectIcons::Resolver.reset!
      Setting.plugin_redmine_project_icons = {
        'show_in_project_list' => '1', 'show_in_issue_lists' => '1',
        'show_in_header' => '1', 'show_in_planning' => '1'
      }
    end

    def store_icon(project, name = 'square.png', type = 'image/png', color: nil)
      icon = project.project_icon || project.build_project_icon
      icon.color = color
      icon.store_icon!(icon_upload(name, type))
      RedmineProjectIcons::Resolver.reset!
      icon
    end

    def store_color(project, color)
      icon = project.project_icon || project.build_project_icon
      icon.update!(color: color)
      RedmineProjectIcons::Resolver.reset!
      icon
    end

    # Breite und Höhe aus dem PNG-Kopf (IHDR)
    def png_size(path)
      File.binread(path, 24)[16, 8].unpack('NN')
    end
  end
end
