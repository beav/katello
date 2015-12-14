require 'fileutils'
require 'English'
require 'pry'

module Actions
  module Katello
    module Repository
      class UploadErrata < Actions::EntryAction
        def plan(repository, errata)
          action_subject(repository)
          sequence do
            concurrence do
              errata.each do |erratum|
                sequence do
                  upload_request = plan_action(Pulp::Repository::CreateUploadRequest)
                  plan_action(Pulp::Repository::UploadFile,
                              upload_id: upload_request.output[:upload_id])
                  # Pulp exposes some of its internal data structure here
                  plan_action(Pulp::Repository::ImportUpload,
                              pulp_id: repository.pulp_id,
                              unit_type_id: 'erratum',
                              unit_metadata: erratum["unit_metadata"],
                              unit_key: erratum["unit_key"],
                              upload_id: upload_request.output[:upload_id])
                  plan_action(Pulp::Repository::DeleteUploadRequest,
                              upload_id: upload_request.output[:upload_id])
                end
              end
            end
            plan_action(FinishUpload, repository)
          end
        end

        def humanized_name
          _("Upload errata into")
        end

      end
    end
  end
end
