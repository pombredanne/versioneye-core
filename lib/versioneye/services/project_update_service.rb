class ProjectUpdateService < Versioneye::Service

  A_TASK_RUNNING = 'running'
  A_TASK_DONE    = 'done'
  A_TASK_TTL     = 420 # 420 seconds = 7 minutes

  def self.update_async project, send_email = false
    return nil if not_updateable?( project )

    task_key    = "task_#{project.ids}"
    task_status = cache.get( task_key )
    if task_status.to_s.eql?(A_TASK_RUNNING)
      log.debug "project #{project.ids} is still processed"
      return task_status
    end

    task_status = A_TASK_RUNNING
    cache.set( task_key, task_status, A_TASK_TTL )

    msg = "project_#{project.ids}:::#{send_email}"
    ProjectUpdateProducer.new( msg )

    task_status
  end


  def self.status_for project_id
    task_key    = "task_#{project_id}"
    task_status = cache.get( task_key )
    task_status = A_TASK_DONE if task_status.to_s.empty?
    task_status
  end


  def self.update project, send_email = false
    return nil if not_updateable?( project )

    project = update_single project, send_email
    project.children.each do |child_project|
      child_project.license_whitelist_id = project.license_whitelist_id
      child_project.save
      update_single child_project, send_email
    end
    ProjectService.update_sums( project )
    reset_badge project.ids
    project
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.update_single project, send_email = false
    return nil if not_updateable?( project )

    project.parsing_errors = []
    updater = UpdateStrategy.updater_for project.source
    updater.update project, send_email
    reset_badge project.ids
    project
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.update_from_upload project, file, user = nil, api_created = false
    return nil if project.nil?

    new_project = ProjectParseService.project_from file
    if new_project.nil?
      raise "project file could not be parsed. Maybe the file is empty? Or not valid?"
    end
    cache.delete( new_project.id.to_s )
    cache.delete( project.id.to_s )
    project.update_from new_project
    project.source = Project::A_SOURCE_API if api_created
    ProjectService.update_license_numbers! project
    update_numbers project

    project
  end


  private

    def self.reset_badge id
      cache.delete( id )
      cache.delete( "#{id}__flat" )
      Badge.where( :key => id.to_s ).delete
      Badge.where( :key => "#{id}__flat" ).delete
    end


    def self.update_numbers project
      if !project.parent_id.to_s.empty?
        ProjectService.update_sums project.parent
      else
        ProjectService.update_sums project
      end
    rescue => e
      log.error e.message
      log.error e.backtrace.join("\n")
    end


    def self.not_updateable?( project )
      return true if project.nil?
      return true if (project.user_id.nil? || project.user.nil?) && (project.organisation.nil?)
      return true if project.user && project.user.deleted_user == true
      return false
    end


end
