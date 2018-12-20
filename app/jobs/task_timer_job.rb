class TaskTimerJob < CaseflowJob
  queue_as :low_priority
  application_attr :queue

  def perform(task_timer)
  	RequestStore.store[:application] = "queue"
    RequestStore.store[:current_user] = User.system_user

    TaskTimer.requires_processing.each do |task_timer|
      TaskTimer.task.when_timer_ends
    end
  end
end