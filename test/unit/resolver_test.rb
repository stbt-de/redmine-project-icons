# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ResolverTest < ActiveSupport::TestCase
  include RedmineProjectIcons::TestHelper

  fixtures :projects

  def setup
    reset_project_icons
  end

  def teardown
    reset_project_icons
  end

  def test_ohne_icon_und_farbe_nichts
    assert_nil RedmineProjectIcons::Resolver.effective(Project.find(1))
  end

  def test_unterprojekt_erbt_icon_und_farbe
    store_icon(Project.find(1), color: '#1d4ed8')
    effective = RedmineProjectIcons::Resolver.effective(Project.find(3))

    assert effective.icon?
    assert_equal 1, effective.source_project_id
    assert_equal '#1d4ed8', effective.color
  end

  def test_eigene_farbe_schlaegt_geerbte_das_icon_bleibt_geerbt
    store_icon(Project.find(1), color: '#1d4ed8')
    store_color(Project.find(3), '#b91c1c')
    effective = RedmineProjectIcons::Resolver.effective(Project.find(3))

    assert_equal 1, effective.source_project_id
    assert_equal '#b91c1c', effective.color
    assert_equal 3, effective.color_project_id
  end

  def test_naechster_vorfahr_gewinnt
    store_icon(Project.find(1))
    store_icon(Project.find(5), 'photo.jpg', 'image/jpeg')
    # Projekt 6 ist Unterprojekt von 5, das Unterprojekt von 1 ist
    assert_equal 5, RedmineProjectIcons::Resolver.effective(Project.find(6)).source_project_id
  end

  def test_geschwister_erben_nicht_voneinander
    store_icon(Project.find(3))
    assert_nil RedmineProjectIcons::Resolver.effective(Project.find(4))
  end

  def test_rasterbild_wird_auf_128_px_eingepasst
    icon = store_icon(Project.find(1), 'photo.jpg', 'image/jpeg')
    assert_equal 'image/png', icon.content_type
    assert_equal [128, 128], png_size(icon.path)
  end

  def test_svg_bleibt_svg
    icon = store_icon(Project.find(1), 'logo.svg', 'image/svg+xml')
    assert_equal 'image/svg+xml', icon.content_type
    assert icon.filename.end_with?('.svg')
  end

  def test_ungueltige_farbe_wird_abgelehnt
    icon = Project.find(1).build_project_icon(color: 'rot')
    assert_not icon.valid?
  end

  def test_icon_verschwindet_mit_dem_projekt
    project = Project.generate!
    icon = store_icon(project)
    path = icon.path
    assert File.exist?(path)

    project.destroy
    assert_not File.exist?(path)
    assert_nil ProjectIcon.find_by(project_id: project.id)
  end
end
