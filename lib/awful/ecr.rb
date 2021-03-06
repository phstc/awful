require 'base64'

module Awful
  class ECR < Cli
    no_commands do
      def ecr
        @ecr ||= Aws::ECR::Client.new
      end
    end

    desc 'ls', 'list commands'
    method_option :long, aliases: '-l', type: :boolean, default: false, desc: 'Long listing'
    def ls
      ecr.describe_repositories.repositories.tap do |repos|
        if options[:long]
          print_table repos.map { |r| [r.repository_name, r.registry_id, r.repository_arn] }
        else
          puts repos.map(&:repository_name)
        end
      end
    end

    desc 'dump [REPOS]', 'describe given or all repositories as yaml'
    def dump(*repos)
      repos = nil if repos.empty? # omit this arg to show all repos
      ecr.describe_repositories(repository_names: repos).repositories.tap do |list|
        list.each do |repo|
          puts YAML.dump(stringify_keys(repo.to_h))
        end
      end
    end

    desc 'create REPO', 'create a repository'
    def create(repository)
      ecr.create_repository(repository_name: repository)
    end

    desc 'delete REPO', 'delete a repository'
    method_option :force, aliases: '-f', type: :boolean, default: false, desc: 'Force the deletion of the repository if it contains images'
    def delete(repository)
      if yes? "Really delete repository #{repository}?", :yellow
        ecr.delete_repository(repository_name: repository, force: options[:force])
      end
    end

    desc 'auth [REGISTRIES]', 'dump authorization details for registries (or default)'
    def auth(*registries)
      registries = nil if registries.empty?
      ecr.get_authorization_token(registry_ids: registries).authorization_data.tap do |auths|
        auths.each do |auth|
          puts YAML.dump(stringify_keys(auth.to_h))
        end
      end
    end

    desc 'login [REGISTRIES]', 'run docker login for registry'
    method_option :email, aliases: '-E', type: :string,  default: 'none', desc: 'Email for docker login command'
    method_option :print, aliases: '-p', type: :boolean, default: false,  desc: 'Print docker login command instead of running it'
    def login(*registries)
      cmd = options[:print] ? :puts : :system
      registries = nil if registries.empty?
      ecr.get_authorization_token(registry_ids: registries).authorization_data.tap do |auths|
        auths.each do |auth|
          user, pass = Base64.decode64(auth.authorization_token).split(':')
          send(cmd, "docker login -u #{user} -p #{pass} -e #{options[:email]} #{auth.proxy_endpoint}")
        end
      end
    end

    desc 'images REPO', 'list images for repo'
    method_option :long, aliases: '-l', type: :boolean, default: false, desc: 'Long listing'
    def images(repository)
      ecr.list_images(repository_name: repository).image_ids.tap do |images|
        if options[:long]
          print_table images.map { |i| [i.image_tag, i.image_digest] }
        else
          puts images.map(&:image_tag)
        end
      end
    end
  end
end