# frozen_string_literal: true

# Projekt-Icons: ausliefern (für alle, die das Projekt sehen dürfen) und
# pflegen (für alle, die das Projekt bearbeiten dürfen).
class ProjectIconsController < ApplicationController
  before_action :find_project_for_icon
  before_action :require_edit_permission, except: :show

  def show
    effective = RedmineProjectIcons::Resolver.effective(@project)
    return head(:not_found) unless effective&.icon?

    owner = ProjectIcon.find_by(project_id: effective.source_project_id)
    return head(:not_found) unless owner&.icon?

    # Nur im Browser zwischenspeichern, nicht in geteilten Caches
    if params[:v] == effective.digest
      expires_in 1.year, public: false
    else
      expires_now
    end
    response.headers['X-Content-Type-Options'] = 'nosniff'
    # SVG kann Scripte enthalten: beim direkten Aufruf nichts ausführen
    response.headers['Content-Security-Policy'] = "default-src 'none'; style-src 'unsafe-inline'; sandbox"

    send_file owner.path, type: owner.content_type, disposition: 'inline'
  end

  # Icon hochladen und/oder Farbe setzen
  def update
    icon = @project.project_icon || @project.build_project_icon
    icon.color = chosen_color

    begin
      # Farbe zuerst prüfen, damit eine ungültige Eingabe nicht erst beim
      # Speichern des Bildes auffällt
      raise ProjectIcon::InvalidUpload, :color unless icon.valid?

      params[:file].present? ? icon.store_icon!(params[:file]) : icon.save!
      flash[:notice] = l(:notice_successful_update)
    rescue ProjectIcon::InvalidUpload => e
      flash[:error] = l(:"error_project_icons_#{e.reason}")
    end
    redirect_to settings_project_path(@project, tab: 'project_icon')
  end

  # Eigenes Icon entfernen (die Farbe bleibt)
  def destroy
    @project.project_icon&.remove_icon!
    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, tab: 'project_icon')
  end

  private

  def find_project_for_icon
    @project = Project.find(params[:id])
    render_404 unless @project.visible?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def require_edit_permission
    deny_access unless User.current.allowed_to?(:edit_project, @project)
  end

  # Palette, eigene Farbe oder leer (= vom Elternprojekt erben)
  def chosen_color
    choice = params[:color].to_s
    choice == 'custom' ? params[:custom_color].to_s.strip : choice
  end
end
