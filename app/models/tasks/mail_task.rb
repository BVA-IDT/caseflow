class MailTask < GenericTask
  # Skip unique verification for mail tasks since multiple mail tasks of each type can be created.
  def verify_org_task_unique; end

  class << self
    def subclasses
      [
        AddressChangeMailTask,
        EvidenceOrArgumentMailTask,
        PowerOfAttorneyRelatedMailTask
      ]
    end

    def subclass_routing_options
      MailTask.subclasses.map { |subclass| { value: subclass.name, label: subclass.label } }
    end

    def create_from_params(params, user)
      verify_user_can_create!(user)

      root_task = RootTask.find(params[:parent_id])
      unless root_task
        fail(Caseflow::Error::NoRootTask, message: "Could not find root task for appeal with ID #{params[:appeal]}")
      end

      mail_task = create!(
        appeal: root_task.appeal,
        parent_id: root_task.id,
        assigned_to: MailTeam.singleton
      )

      # Create a child task off of the mail organization's task so we can track how that task was created.
      create_child_task(mail_task, user, params)
    end

    def verify_user_can_create!(user)
      unless MailTeam.singleton.user_has_access?(user)
        fail Caseflow::Error::ActionForbiddenError, message: "Current user cannot create a mail task"
      end
    end
  end

  def label
    self.class.label
  end
end

# TODO: Flesh out routing rules based on status of appeal.
# Should incoming mail tasks be automatically routed to members of the VLJ support staff?
class AddressChangeMailTask < MailTask
  class << self
    def label
      COPY::ADDRESS_CHANGE_MAIL_TASK_LABEL
    end

    def get_child_task_assignee(_params)
      Colocated.singleton
    end
  end
end

class EvidenceOrArgumentMailTask < MailTask
  class << self
    def label
      COPY::EVIDENCE_OR_ARGUMENT_MAIL_TASK_LABEL
    end

    def get_child_task_assignee(_params)
      Colocated.singleton
    end
  end
end

class PowerOfAttorneyRelatedMailTask < MailTask
  class << self
    def label
      COPY::POWER_OF_ATTORNEY_MAIL_TASK_LABEL
    end

    def get_child_task_assignee(_params)
      Colocated.singleton
    end
  end
end
