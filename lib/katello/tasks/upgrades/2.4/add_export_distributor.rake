namespace :katello do
  namespace :upgrades do
    namespace '2.4' do
      task :add_export_distributor => ["environment"]  do
        User.current = User.anonymous_api_admin
        puts _("Adding the export distributor to existing repositories")

        Katello::Product.find_each do |product|
          product.repositories.each do |repo|
            if not repo.distributors.any? { |r| r[:distributor_type_id] == 'export_distributor'}
              ForemanTasks.sync_task(::Actions::Katello::Repository::AddExportDistributor, repo)
            end
          end
        end
      end
    end
  end
end
