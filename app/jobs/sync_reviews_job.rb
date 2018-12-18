# This job will sync end products & contentions that we created for decision reviews
class SyncReviewsJob < CaseflowJob
  queue_as :low_priority
  application_attr :intake

  DEFAULT_EP_LIMIT = 100

  def perform(args = {})
    RequestStore.store[:application] = "intake"
    RequestStore.store[:current_user] = User.system_user

    # specified limit of end products that will be synced
    limit = args["limit"] || DEFAULT_EP_LIMIT

    perform_end_product_syncs(limit)
    perform_ramp_refiling_reprocessing
    perform_decision_review_processing(limit)
    perform_decision_rating_issues_syncs(limit)
  end

  private

  def perform_end_product_syncs(limit)
    EndProductEstablishment.order_by_sync_priority.limit(limit).each do |end_product_establishment|
      EndProductSyncJob.perform_later(end_product_establishment.id)
    end
  end

  def perform_ramp_refiling_reprocessing
    RampRefiling.need_to_reprocess.each do |ramp_refiling|
      ramp_refiling.create_end_product_and_contentions!
    rescue StandardError => e
      # Rescue and capture errors so they don't cause the job to stop
      Raven.capture_exception(e, extra: { ramp_refiling_id: ramp_refiling.id })
    end
  end

  def perform_decision_review_processing(limit)
    # RequestIssuesUpdate is not a DecisionReview subclass but it acts like one
    # for the purposes of DecisionReviewProcessJob
    [Appeal, HigherLevelReview, SupplementalClaim, RequestIssuesUpdate].each do |klass|
      klass.requires_processing.limit(limit).each do |review|
        DecisionReviewProcessJob.perform_later(review)
      end
    end
  end

  def perform_decision_rating_issues_syncs(limit)
    RequestIssue.requires_processing.limit(limit).each do |request_issue|
      DecisionIssueSyncJob.perform_later(request_issue)
    end
  end
end
