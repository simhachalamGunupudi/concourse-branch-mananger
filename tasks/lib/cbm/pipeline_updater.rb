require 'process_helper'
require 'tmpdir'
require 'open-uri'

module Cbm
  # Creates/updates pipeline via fly
  class PipelineUpdater
    include Logger
    include ProcessHelper

    attr_reader :url, :username, :password, :team, :pipeline_file, :fly_path
    attr_reader :load_vars_from_entries, :pipeline_name

    # TODO: do http://www.refactoring.com/catalog/introduceParameterObject.html
    # rubocop:disable Metrics/ParameterLists
    def initialize(url, username, password, team, pipeline_file, load_vars_from_entries, pipeline_name)
      @url = url
      @username = username
      @password = password
      @team = team
      @pipeline_file = pipeline_file
      @fly_path = "#{Dir.mktmpdir}/fly"
      @load_vars_from_entries = load_vars_from_entries
      @pipeline_name = pipeline_name
    end

    def set_pipeline
      download_fly

      log 'Logging into concourse...'
      team_argument = team != nil && team != "" ? "--team-name=#{team}" : ''
      process(
        "#{fly_path} --target=concourse login --concourse-url=#{url} #{team_argument}",
        timeout: 5,
        input_lines: [username, password])

      log 'Updating pipeline...'
      process(generate_set_pipeline_cmd, timeout: 5, input_lines: %w(y))

      log 'Unpausing pipeline...'
      unpause_pipeline_cmd = "#{fly_path} --target=concourse unpause-pipeline " \
        "--pipeline=#{pipeline_name}"
      process(unpause_pipeline_cmd, timeout: 5)
    end

    private

    def generate_set_pipeline_cmd
      load_vars_from_options = load_vars_from_entries.reduce('') do |options, entry|
        "#{options}--load-vars-from=#{entry} "
      end.strip
      "#{fly_path} --target=concourse set-pipeline --config=#{pipeline_file} " \
        "--pipeline=#{pipeline_name} #{load_vars_from_options}"
    end

    def download_fly
      log 'Downloading fly executable...'
    end
  end
end
