# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'
require 'timeout'

# Icon und Farbe eines Projekts.
#
# Das Bild liegt im Redmine-Dateiverzeichnis (files/redmine_project_icons),
# damit es mit den Anhängen gesichert wird. Rasterbilder werden auf
# SIZE × SIZE px gebracht (ganz sichtbar, transparent aufgefüllt – Logos sind
# oft breit), SVG wird unverändert gespeichert und in einer Sandbox
# ausgeliefert.
class ProjectIcon < ApplicationRecord
  RASTER_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  SVG_TYPE = 'image/svg+xml'
  MAX_SIZE = 2 * 1024 * 1024
  SIZE = 128
  COLOR_FORMAT = /\A#[0-9a-f]{6}\z/i

  # Ungültiger Upload; reason ist ein Symbol für die Fehlermeldung
  class InvalidUpload < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  belongs_to :project

  validates :project_id, presence: true, uniqueness: true
  validates :color, format: { with: COLOR_FORMAT }, allow_blank: true

  before_validation { self.color = color.to_s.strip.downcase.presence }
  after_destroy :remove_files

  def self.directory
    File.join(Attachment.storage_path, 'redmine_project_icons')
  end

  def self.convert_bin
    Redmine::Thumbnail::CONVERT_BIN
  end

  def icon?
    filename.present? && File.file?(path)
  end

  def path
    File.join(self.class.directory, File.basename(filename.to_s))
  end

  def store_icon!(upload)
    raise InvalidUpload, :blank unless upload.respond_to?(:read) && upload.respond_to?(:original_filename)
    raise InvalidUpload, :too_large if upload.size > MAX_SIZE

    data = upload.read.to_s.b
    raise InvalidUpload, :blank if data.empty?

    # Typ nach Inhalt, nicht nach Dateiname
    type = Marcel::MimeType.for(StringIO.new(data), name: upload.original_filename)
    if type == SVG_TYPE
      content, extension = data, 'svg'
    elsif RASTER_TYPES.include?(type)
      content, extension, type = process(data, type), 'png', 'image/png'
    else
      raise InvalidUpload, :type
    end

    digest = Digest::SHA256.hexdigest(content)[0, 16]
    FileUtils.mkdir_p(self.class.directory)
    remove_files
    self.filename = "#{project_id}-#{digest}.#{extension}"
    self.content_type = type
    self.digest = digest
    File.binwrite(path, content)
    save!
  end

  def remove_icon!
    remove_files
    self.filename = self.content_type = self.digest = nil
    save!
  end

  private

  def remove_files
    return unless project_id

    Dir.glob(File.join(self.class.directory, "#{project_id}-*")).each { |file| FileUtils.rm_f(file) }
  end

  # Ganz sichtbar in ein Quadrat einpassen, Rand transparent, PNG ohne
  # Metadaten. Bei GIF nur das erste Bild.
  def process(data, type)
    Dir.mktmpdir('redmine_project_icons') do |dir|
      source = File.join(dir, 'source')
      target = File.join(dir, 'icon.png')
      File.binwrite(source, data)

      input = type == 'image/gif' ? "#{source}[0]" : source
      command = [
        self.class.convert_bin, input,
        '-auto-orient', '-strip',
        '-thumbnail', "#{SIZE}x#{SIZE}",
        '-background', 'none', '-gravity', 'center', '-extent', "#{SIZE}x#{SIZE}",
        "png:#{target}"
      ]
      raise InvalidUpload, :processing unless run(command) && File.file?(target)

      File.binread(target)
    end
  end

  # ImageMagick ohne Shell starten, mit Redmines Zeitlimit für Vorschaubilder
  def run(command)
    pid = Process.spawn(*command, out: File::NULL, err: File::NULL)
    Timeout.timeout(Redmine::Configuration['thumbnails_generation_timeout'].to_i) do
      _, status = Process.wait2(pid)
      status.success?
    end
  rescue Timeout::Error
    Process.kill('KILL', pid)
    Process.detach(pid)
    false
  rescue SystemCallError
    false
  end
end
