class TasksController < ApplicationController
  include Errors

  before_action :verify_task_access, only: [:create]
  skip_before_action :deny_vso_access, only: [:create, :index, :update, :for_appeal]

  TASK_CLASSES = {
    ColocatedTask: ColocatedTask,
    AttorneyTask: AttorneyTask,
    GenericTask: GenericTask,
    QualityReviewTask: QualityReviewTask,
    JudgeAssignTask: JudgeAssignTask,
    ScheduleHearingTask: ScheduleHearingTask,
    MailTask: MailTask,
    InformalHearingPresentationTask: InformalHearingPresentationTask
  }.freeze

  def set_application
    RequestStore.store[:application] = "queue"
  end

  # e.g, GET /tasks?user_id=xxx&role=colocated
  #      GET /tasks?user_id=xxx&role=attorney
  #      GET /tasks?user_id=xxx&role=judge
  def index
    tasks = queue_class.new(user: user).tasks
    render json: { tasks: json_tasks(tasks) }
  end

  # To create colocated task
  # e.g, for legacy appeal => POST /tasks,
  # { type: ColocatedTask,
  #   external_id: 123423,
  #   title: "poa_clarification",
  #   instructions: "poa is missing"
  # }
  # for ama appeal = POST /tasks,
  # { type: ColocatedTask,
  #   external_id: "2CE3BEB0-FA7D-4ACA-A8D2-1F7D2BDFB1E7",
  #   title: "something",
  #   parent_id: 2
  #  }
  #
  # To create attorney task
  # e.g, for ama appeal => POST /tasks,
  # { type: AttorneyTask,
  #   external_id: "2CE3BEB0-FA7D-4ACA-A8D2-1F7D2BDFB1E7",
  #   title: "something",
  #   parent_id: 2,
  #   assigned_to_id: 23
  #  }
  def create
    return invalid_type_error unless task_class

    tasks = task_class.create_many_from_params(create_params, current_user)

    tasks.each { |task| return invalid_record_error(task) unless task.valid? }

    tasks_to_return = (queue_class.new(user: current_user).tasks + tasks).uniq

    render json: { tasks: json_tasks(tasks_to_return) }
  end

  # To update attorney task
  # e.g, for ama/legacy appeal => PATCH /tasks/:id,
  # {
  #   assigned_to_id: 23
  # }
  # To update colocated task
  # e.g, for ama/legacy appeal => PATCH /tasks/:id,
  # {
  #   status: :on_hold,
  #   on_hold_duration: "something"
  # }
  def update
    tasks = task.update_from_params(update_params, current_user)
    tasks.each { |t| return invalid_record_error(t) unless t.valid? }

    tasks_to_return = (queue_class.new(user: current_user).tasks + tasks).uniq

    render json: { tasks: json_tasks(tasks_to_return) }
  end

  def for_appeal
    no_cache
    RootTask.find_or_create_by!(appeal: appeal)
    # VSO users should only get tasks assigned to them or their organization.
    if current_user.vso_employee?
      return json_vso_tasks
    end

    tasks = appeal.tasks
    if %w[attorney judge].include?(user_role) && appeal.is_a?(LegacyAppeal)
      legacy_appeal_tasks = LegacyWorkQueue.tasks_with_appeals_by_appeal_id(params[:appeal_id], user_role)
      tasks = (legacy_appeal_tasks + tasks).uniq
    end

    render json: {
      tasks: json_tasks(tasks)[:data]
    }
  end

  private

  def can_assign_task?
    return true if create_params.first[:appeal].is_a?(Appeal)
    super
  end

  def verify_task_access
    if current_user.vso_employee? && task_class != InformalHearingPresentationTask
      fail Caseflow::Error::ActionForbiddenError, message: "VSOs cannot create that task."
    end

    redirect_to("/unauthorized") unless can_assign_task?
  end

  def queue_class
    (user_role == "attorney") ? AttorneyQueue : GenericQueue
  end

  def user_role
    params[:role].to_s.empty? ? "generic" : params[:role].downcase
  end

  def user
    @user ||= User.find(params[:user_id])
  end
  helper_method :user

  def task_class
    TASK_CLASSES[create_params.first[:type].try(:to_sym)]
  end

  def appeal
    @appeal ||= Appeal.find_appeal_by_id_or_find_or_create_legacy_appeal_by_vacols_id(params[:appeal_id])
  end

  def invalid_type_error
    render json: {
      "errors": [
        "title": "Invalid Task Type Error",
        "detail": "Task type is invalid, valid types: #{TASK_CLASSES.keys}"
      ]
    }, status: 400
  end

  def task
    @task ||= Task.find(params[:id])
  end

  def create_params
    @create_params ||= [params.require("tasks")].flatten.map do |task|
      task = task.permit(:type, :instructions, :action, :label, :assigned_to_id,
                         :assigned_to_type, :external_id, :parent_id, business_payloads: [:description, values: {}])
        .merge(assigned_by: current_user)
        .merge(appeal: Appeal.find_appeal_by_id_or_find_or_create_legacy_appeal_by_vacols_id(task[:external_id]))

      task.delete(:external_id)
      task = task.merge(assigned_to_type: User.name) if !task[:assigned_to_type]

      # Allow actions to be passed with either the key "action" or "label" while we transition to using "label" in place
      # of "action" so requests coming from browsers that have older versions of the javascript bundle succeed.
      task = task.merge(action: task.delete(:label)) if task[:label]

      task
    end
  end

  def update_params
    params.require("task").permit(
      :status,
      :on_hold_duration,
      :assigned_to_id,
      :instructions,
      reassign: [:assigned_to_id, :assigned_to_type, :instructions],
      business_payloads: [:description, values: {}]
    )
  end

  def json_vso_tasks
    # For now we just return tasks that are assigned to the user. In the future,
    # we will add tasks that are assigned to the user's organization.
    tasks = GenericQueue.new(user: current_user).tasks

    render json: {
      tasks: json_tasks(tasks)[:data]
    }
  end

  def json_legacy_tasks(tasks, role)
    ActiveModelSerializers::SerializableResource.new(
      tasks,
      each_serializer: ::WorkQueue::LegacyTaskSerializer,
      role: role
    ).as_json
  end

  def eager_load_legacy_appeals_for_tasks(tasks)
    # Make a single request to VACOLS to grab all of the rows we want here?
    legacy_appeal_ids = tasks.select { |t| t.appeal.is_a?(LegacyAppeal) }.map(&:appeal).pluck(:vacols_id)

    # Load the VACOLS case records associated with legacy tasks into memory in a single batch.
    cases = AppealRepository.vacols_records_for_appeals(legacy_appeal_ids) || []

    # Associate the cases we pulled from VACOLS to the appeals of the tasks.
    tasks.each do |t|
      if t.appeal.is_a?(LegacyAppeal)
        case_record = cases.select { |cr| cr.id == t.appeal.vacols_id }.first
        AppealRepository.set_vacols_values(appeal: t.appeal, case_record: case_record) if case_record
      end
    end
  end

  def json_tasks(tasks)
    ActiveModelSerializers::SerializableResource.new(
      eager_load_legacy_appeals_for_tasks(tasks),
      user: current_user,
      role: user_role
    ).as_json
  end
end
