module Actions
  module Katello
    module Repository
      class AddExportDistributor < Actions::Base
        def plan(repo)
          ::User.current = ::User.anonymous_admin
          repo = ::Katello::Repository.find(repo.id)
          plan_action(Pulp::Repository::AssociateDistributor,
                      repo_id: repo[:pulp_id],
                      config: {:http => true, :https => true},
                      type_id: 'export_distributor') 
        end
      end
    end
  end
end
