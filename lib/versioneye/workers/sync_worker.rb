class SyncWorker < Worker


  def work
    connection = get_connection
    connection.start
    channel = connection.create_channel
    channel.prefetch(1)
    queue   = channel.queue("sync_db", :durable => true)

    multi_log " [*] SyncWorker waiting for messages in #{queue.name}. To exit press CTRL+C"

    begin
      queue.subscribe(:manual_ack => true, :block => true) do |delivery_info, properties, message|
        multi_log " [x] SyncWorker received #{delivery_info.routing_key}:#{message}"
        process_work message
        channel.ack(delivery_info.delivery_tag)
        multi_log " [x] SyncWorker job done for #{delivery_info.routing_key}:#{message}"
      end
    rescue => e
      log.error e.message
      log.error e.backtrace.join("\n")
      connection.close
    end
  end


  def process_work message
    return nil if message.to_s.empty?

    if message.match(/\Aproject\:\:/)
      project_id = message.split("::")[1]
      project = Project.find project_id
      if project.nil?
        log.error "   [x] SyncWorker: No project found #{project_id}"
        return nil
      end
      SyncService.sync_project project
    elsif message.match(/\Aall_products/)
      SyncService.sync_all_products
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


end
