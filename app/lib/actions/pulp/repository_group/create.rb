module Actions
  module Pulp
    module RepositoryGroup
      class Create < Pulp::Abstract
        include Helpers::Presenter

        input_format do
          param :id
          param :pulp_ids
        end

        def run
          distributors = [{:distributor_type_id => 'group_export_distributor',
                           :distributor_config => {:http => false,
                                                   :https => false},
                           :auto_publish => false,
                           :distributor_id => 'group-export-dist'}]
          pulp_resources.
            repository_group.create(input[:id],
                                    optional = {:id => input[:id],
                                                :repo_ids => input[:pulp_ids],
                                                :display_name => "temporary group for export",
                                                :distributors => distributors})
        end
      end
    end
  end
end
