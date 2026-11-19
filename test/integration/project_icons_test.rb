# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ProjectIconsTest < Redmine::IntegrationTest
  include RedmineProjectIcons::TestHelper

  fixtures :users, :email_addresses, :user_preferences, :roles, :members, :member_roles,
           :projects, :enabled_modules, :trackers, :projects_trackers, :issue_statuses,
           :issues, :enumerations, :versions, :issue_categories

  def setup
    reset_project_icons
  end

  def teardown
    reset_project_icons
  end

  # --- Pflege --------------------------------------------------------------

  def test_reiter_darstellung_in_den_projekteinstellungen
    log_user('jsmith', 'jsmith')
    get '/projects/ecookbook/settings/project_icon'
    assert_response :success
    assert_select 'form#project-icons-form input[type=file][name=file]'
    assert_select 'form#project-icons-form input[type=radio][name=color]', 14
  end

  # Farbe ist nur Fallback: gilt ein Icon (auch geerbt), sagt der Reiter das
  def test_hinweis_wenn_farbe_wegen_icon_nicht_sichtbar
    log_user('jsmith', 'jsmith')
    store_color(Project.find(1), '#1d4ed8')
    get '/projects/ecookbook/settings/project_icon'
    assert_select 'form#project-icons-form'
    assert_select '.project-icons-color-unused', 0

    store_icon(Project.find(1), color: '#1d4ed8')
    get '/projects/ecookbook/settings/project_icon'
    assert_select '.project-icons-color-unused'
  end

  def test_icon_hochladen_mit_palettenfarbe
    log_user('jsmith', 'jsmith')
    post '/projects/ecookbook/icon', params: { file: icon_upload('square.png', 'image/png'), color: '#1d4ed8' }
    assert_redirected_to '/projects/ecookbook/settings/project_icon'

    icon = Project.find(1).project_icon
    assert icon.icon?
    assert_equal '#1d4ed8', icon.color
  end

  def test_eigene_farbe
    log_user('jsmith', 'jsmith')
    post '/projects/ecookbook/icon', params: { color: 'custom', custom_color: '#ABCDEF' }
    assert_equal '#abcdef', Project.find(1).project_icon.color
  end

  def test_ungueltige_eigene_farbe_mit_datei_wird_nichts_gespeichert
    log_user('jsmith', 'jsmith')
    post '/projects/ecookbook/icon', params: { file: icon_upload('square.png', 'image/png'), color: 'custom', custom_color: 'blau' }
    assert_equal I18n.t(:error_project_icons_color, locale: :en), flash[:error]
    assert_nil ProjectIcon.find_by(project_id: 1)
  end

  def test_als_svg_getarnte_html_datei_wird_abgelehnt
    log_user('jsmith', 'jsmith')
    post '/projects/ecookbook/icon', params: { file: icon_upload('not-an-image.svg', 'image/svg+xml') }
    assert_equal I18n.t(:error_project_icons_type, locale: :en), flash[:error]
    assert_not ProjectIcon.find_by(project_id: 1)&.icon?
  end

  def test_icon_entfernen_behaelt_die_farbe
    store_icon(Project.find(1), color: '#15803d')
    log_user('jsmith', 'jsmith')
    delete '/projects/ecookbook/icon'

    icon = Project.find(1).project_icon
    assert_not icon.icon?
    assert_equal '#15803d', icon.color
  end

  def test_ohne_bearbeitungsrecht_keine_pflege
    # dlopper ist Entwickler in eCookbook; der Rolle das Recht nehmen
    Role.find(2).remove_permission!(:edit_project)
    log_user('dlopper', 'foo')
    post '/projects/ecookbook/icon', params: { color: '#1d4ed8' }
    assert_response :forbidden
    assert_nil ProjectIcon.find_by(project_id: 1)
  end

  # --- Auslieferung --------------------------------------------------------

  def test_unterprojekt_liefert_geerbtes_icon
    store_icon(Project.find(1))
    get '/projects/subproject1/icon'
    assert_response :success
    assert_equal 'image/png', response.media_type
  end

  def test_svg_mit_sandbox
    store_icon(Project.find(1), 'logo.svg', 'image/svg+xml')
    get '/projects/ecookbook/icon'
    assert_response :success
    assert_includes response.headers['Content-Security-Policy'], 'sandbox'
  end

  def test_privates_projekt_nicht_fuer_anonyme
    store_icon(Project.find(5))
    get '/projects/private-child/icon'
    assert_response :not_found
  end

  # --- Anzeige -------------------------------------------------------------

  # In der Projektliste steht ein Unterprojekt unter seinem Hauptprojekt –
  # ein geerbtes Icon wäre dort nur eine Wiederholung
  def test_projektliste_zeigt_geerbte_icons_bei_unterprojekten_nicht
    store_icon(Project.find(1))
    get '/projects?display_type=board'
    assert_response :success
    assert_select 'a.project.root[href="/projects/ecookbook"] img.project-icon.project-icon-28'
    assert_select 'a.project.child[href="/projects/subproject1"] .project-icon', 0
  end

  def test_projektliste_zeigt_eigenes_icon_eines_unterprojekts
    store_icon(Project.find(1))
    store_icon(Project.find(3), 'photo.jpg', 'image/jpeg')
    get '/projects?display_type=board'
    assert_select 'a.project.child[href="/projects/subproject1"] img.project-icon.project-icon-20'
  end

  def test_projektliste_zeigt_eigene_farbe_eines_unterprojekts_ohne_bilder
    store_color(Project.find(1), '#1d4ed8')
    store_color(Project.find(3), '#b91c1c')
    get '/projects?display_type=board'
    # Kachel mit eigenem Anfangsbuchstaben ("eCookbook Subproject 1")
    assert_select 'a.project.child[href="/projects/subproject1"] span.project-icon-tile[style*="#b91c1c"]', text: 'E'
    assert_select 'a.project.child[href="/projects/subproject2"] .project-icon', 0
  end

  def test_ticketliste_zeigt_geerbtes_icon_weiterhin
    store_icon(Project.find(1))
    get '/projects/subproject1/issues?set_filter=1&c[]=project&c[]=subject'
    assert_select '#header h1 > img.project-icon'
  end

  def test_nur_farbe_ergibt_kachel_mit_anfangsbuchstaben
    store_color(Project.find(1), '#b91c1c')
    get '/projects?display_type=board'
    assert_select 'a[href="/projects/ecookbook"] span.project-icon-tile', text: 'E'
  end

  def test_ticketliste_zeigt_icon_in_der_projektspalte
    store_icon(Project.find(1))
    get '/issues?set_filter=1&c[]=project&c[]=subject'
    assert_select 'td.project a img.project-icon.project-icon-16'
  end

  def test_ticketliste_abschaltbar
    store_icon(Project.find(1))
    Setting.plugin_redmine_project_icons = Setting.plugin_redmine_project_icons.merge('show_in_issue_lists' => '0')
    get '/issues?set_filter=1&c[]=project&c[]=subject'
    assert_select 'td.project .project-icon', 0
  end

  def test_kopf_zeigt_icon_und_daten_fuer_die_projektauswahl
    store_icon(Project.find(1))
    get '/projects/subproject1/issues'
    assert_select '#header h1 > .project-icon'
    assert_select '#header h1 .breadcrumbs .project-icon', 0

    data = JSON.parse(css_select('script#project-icons-data').first.text)
    assert_equal '/projects/subproject1', data['current']
    assert data['projects']['/projects/ecookbook']['icon'].start_with?('/projects/ecookbook/icon?v=')
  end

  def test_ohne_icons_keine_daten_und_kein_script
    get '/projects/ecookbook/issues'
    assert_select 'script#project-icons-data', 0
    assert_select '#header h1 > .project-icon', 0
  end
end
