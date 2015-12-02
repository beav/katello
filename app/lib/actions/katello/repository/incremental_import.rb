require 'pry'

module Actions
  module Katello
    module Repository
      class IncrementalImport < Actions::EntryAction
        middleware.use Actions::Middleware::KeepCurrentUser

        input_format do
          param :id, Integer
        end

        # @param repo
        # @param import_location location of files to import
        def plan(repo, import_location)
          action_subject(repo)
          rpm_files = Dir.glob(File.join(import_location, "*rpm"))

          # this is less than ideal. I confirmed with Pulp team that this is
          # the only way to parse the json files currently to see what's an erratum.
          json_files = Dir.glob(File.join(import_location, "*json"))
          pulp_units = json_files.map { |json_file| JSON.parse(File.read(json_file)) }
          errata = pulp_units.select { |pulp_unit| is_erratum? pulp_unit }

          sequence do
            #output = plan_action(Katello::Repository::UploadFiles, repo, rpm_files).output
            plan_action(Katello::Repository::UploadErrata, repo, errata)
            plan_action(Katello::Repository::UploadFiles, repo, rpm_files)
            contents_changed = true # assume the contents were changed for now
            plan_action(Katello::Repository::IndexContent, :id => repo.id, :contents_changed => contents_changed)
            plan_action(Katello::Foreman::ContentUpdate, repo.environment, repo.content_view, repo)
            plan_action(Katello::Repository::CorrectChecksum, repo)
            plan_self(:id => repo.id, :sync_result => output,
                      :user_id => ::User.current.id, :contents_changed => contents_changed)
            concurrence do
              plan_action(Katello::Repository::UpdateMedia, :repo_id => repo.id, :contents_changed => contents_changed)
              plan_action(Katello::Repository::ErrataMail, repo, nil, contents_changed)
              plan_action(Pulp::Repository::RegenerateApplicability, :pulp_id => repo.pulp_id, :contents_changed => contents_changed)
            end
          end
        end

        def run
          ForemanTasks.async_task(Repository::CapsuleGenerateAndSync, ::Katello::Repository.find(input[:id]))
        end

        def rescue_strategy
          Dynflow::Action::Rescue::Skip
        end

        def finalize
          ::User.current = ::User.anonymous_admin
          repo = ::Katello::Repository.find(input[:id])
          repo.import_system_applicability
        ensure
          ::User.current = nil
        end

        private

        def is_erratum? obj
          obj['unit_key']['id'].present? && obj['unit_metadata']['type'].present? && obj['unit_metadata']['issued'].present?
        end
      end
    end
  end
end
