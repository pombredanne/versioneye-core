require 'benchmark'
require 'dalli'

class GitRepoFileImportWorker < Worker

  A_TASK_TTL = 60 # 60 seconds = 1 minutes

  def work
    connection = get_connection
    connection.start
    channel = connection.create_channel
    channel.prefetch(1)
    queue   = channel.queue("git_repo_file_import", :durable => true)

    multi_log " [*] GitRepoFileImportWorker waiting for messages in #{queue.name}. To exit press CTRL+C"

    begin
      queue.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, body|
        multi_log " [x] GitRepoFileImportWorker received #{body}"
        import body
        channel.ack(delivery_info.delivery_tag)
        multi_log " [x] GitRepoFileImportWorker job done #{body}"
      end
    rescue => e
      log.error "ERROR in GitRepoFileImportWorker: #{e.message}"
      log.error e.backtrace.join("\n")
      connection.close
    end
  end


  private


    def import message
      reload_settings()
      sps = message.split(":::")
      provider  = sps[0]
      username  = sps[1]
      repo_name = sps[2]
      filename  = sps[3]
      branch    = sps[4]
      parent_id = sps[5]
      multi_log "   [x] GitRepoFileImportWorker import for provider: #{provider}, username: #{username}, repo_name: #{repo_name}, filename: #{filename}, branch: #{branch}"

      user = User.find_by_username username
      if user.nil?
        cache.set( message, "error_User `#{username}` not found!", A_TASK_TTL )
        multi_log "   [x] GitRepoFileImportWorker username #{username} not found! Cancel this Job!"
        return
      end

      project = nil
      if provider.eql?("stash")
        project = ProjectImportService.import_from_stash user, repo_name, filename, branch
      elsif provider.eql?("github")
        project = ProjectImportService.import_from_github user, repo_name, filename, branch
      elsif provider.eql?("github_child")
        parent = Project.find parent_id
        project = ProjectImportService.import_child_from_github user, repo_name, filename, branch, parent
      elsif provider.eql?("bitbucket")
        project = ProjectImportService.import_from_bitbucket user, repo_name, filename, branch
      elsif provider.eql?("bitbucket_child")
        parent = Project.find parent_id
        project = ProjectImportService.import_child_from_bitbucket user, repo_name, filename, branch, parent
      end

      if project && project.is_a?(Project)
        cache.set( message, "done_#{project.id.to_s}", A_TASK_TTL )
      end
    rescue => e
      cache.set( message, "error_#{e.message}", A_TASK_TTL )
      log.error "ERROR in GitRepoFileImportWorker: #{e.message}"
      log.error e.backtrace.join("\n")
    end


end
