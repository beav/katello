module Actions
  module Katello
    module Repository
      class Export < Actions::EntryAction
        middleware.use Actions::Middleware::KeepCurrentUser

        input_format do
          param :id, Integer
          param :export_result, Hash
        end

        # @param repo
        # @param pulp_export_task_id in case the export was triggered outside
        #   of Katello and we just need to finish the rest of the orchestration
        def plan(repo, pulp_export_task_id = nil)
          plan_action(Pulp::Repository::DistributorPublish,
                      pulp_id: repo.pulp_id,
                      distributor_type_id: Runcible::Models::ExportDistributor.type_id)
        end

        def run
          output[:export_result] = input[:export_result]
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
