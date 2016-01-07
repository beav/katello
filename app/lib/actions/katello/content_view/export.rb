require 'pry'

module Actions
  module Katello
    module ContentView
      class Export < Actions::EntryAction
        middleware.use Actions::Middleware::KeepCurrentUser

        ISO_OUTPUT_BASEDIR = "/var/lib/pulp/published/yum/master/group_export_distributor/"

        def plan(content_view, export_to_iso, since, iso_size)
          action_subject(content_view)
          content_view.check_ready_to_publish!
          start_date = since ? since.iso8601 : nil

          sequence do
            repo_pulp_ids = content_view.repositories_to_publish.collect { |r| r.pulp_id }
            group_id = "#{::Organization.find_by(:id => content_view.organization_id).label}-#{content_view.label}-v#{content_view.next_version-1}"

            unless since.nil?
              group_id += "-incremental"
            end

            # if exporting to a dir, we want to mimic the way Pulp exports ISO
            # files for consistency.
            export_directory = File.join(Setting['pulp_export_destination'], group_id,
                                         Time.now.getutc.to_f.round(2).to_s)

            plan_action(Pulp::RepositoryGroup::Create, :id => group_id,
                                                       :pulp_ids => repo_pulp_ids)
            plan_action(Pulp::RepositoryGroup::Export, :id => group_id,
                                                       :export_to_iso => export_to_iso,
                                                       :iso_size => iso_size,
                                                       :start_date => start_date,
                                                       :export_directory => export_directory)
            plan_self(:group_id => group_id, :export_to_iso => export_to_iso)
            # NB: the delete will also make Pulp delete our exported data under /var/lib/pulp
            plan_action(Pulp::RepositoryGroup::Delete, :id => group_id)
          end
        end

        def run
            # copy the ISO over if we exported an ISO
            if input[:export_to_iso]
              export_location = File.join(ISO_OUTPUT_BASEDIR, input[:group_id])
              FileUtils.cp_r(export_location, Setting['pulp_export_destination'])
            end
        end

        def humanized_name
          _("Export")
        end

        def rescue_strategy
          Dynflow::Action::Rescue::Skip
        end

      end
    end
  end
end
