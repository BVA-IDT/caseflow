class DecisionReview < ApplicationRecord
  include CachedAttributes
  include Asyncable

  validate :validate_receipt_date

  self.abstract_class = true

  attr_reader :saving_review

  has_many :request_issues, as: :review_request
  has_many :claimants, as: :review_request
  has_many :request_decision_issues, through: :request_issues
  has_many :decision_issues, as: :decision_review
  has_many :tasks, as: :appeal

  before_destroy :remove_issues!

  cache_attribute :cached_serialized_ratings, cache_key: :ratings_cache_key, expires_in: 1.day do
    ratings_with_issues.map(&:serialize)
  end

  # The Asyncable module requires we define these.
  # establishment_submitted_at - when our db is ready to push to exernal services
  # establishment_attempted_at - when our db attempted to push to external services
  # establishment_processed_at - when our db successfully pushed to external services
  # establishment_error        - capture exception messages on failures

  class << self
    def submitted_at_column
      :establishment_submitted_at
    end

    def attempted_at_column
      :establishment_attempted_at
    end

    def processed_at_column
      :establishment_processed_at
    end

    def error_column
      :establishment_error
    end

    def ama_activation_date
      if FeatureToggle.enabled?(:use_ama_activation_date)
        Constants::DATES["AMA_ACTIVATION"].to_date
      else
        Constants::DATES["AMA_ACTIVATION_TEST"].to_date
      end
    end

    def review_title
      to_s.underscore.titleize
    end
  end

  def serialized_ratings
    return unless receipt_date
    return unless can_contest_rating_issues?

    cached_serialized_ratings.each do |rating|
      rating[:issues].each do |rating_issue_hash|
        rating_issue_hash[:timely] = timely_issue?(Date.parse(rating_issue_hash[:promulgation_date].to_s))
        # always re-compute flags that depend on data in our db
        rating_issue_hash.merge!(RatingIssue.deserialize(rating_issue_hash).serialize)
      end
    end
  end

  def veteran_full_name
    veteran&.name&.formatted(:readable_full)
  end

  def number_of_issues
    request_issues.count
  end

  def external_id
    id.to_s
  end

  def ui_hash
    {
      veteran: {
        name: veteran&.name&.formatted(:readable_short),
        fileNumber: veteran_file_number,
        formName: veteran&.name&.formatted(:form),
        ssn: veteran&.ssn
      },
      relationships: veteran&.relationships,
      claimant: claimant_participant_id,
      veteranIsNotClaimant: veteran_is_not_claimant,
      receiptDate: receipt_date.to_formatted_s(:json_date),
      legacyOptInApproved: legacy_opt_in_approved,
      legacyAppeals: serialized_legacy_appeals,
      ratings: serialized_ratings,
      requestIssues: request_issues.map(&:ui_hash),
      decisionIssues: decision_issues.map(&:ui_hash),
      activeNonratingRequestIssues: active_nonrating_request_issues.map(&:ui_hash),
      contestableIssuesByDate: contestable_issues.map(&:serialize),
      editIssuesUrl: caseflow_only_edit_issues_url
    }
  end

  def timely_issue?(decision_date)
    return true unless receipt_date && decision_date

    decision_date >= (receipt_date - Rating::ONE_YEAR_PLUS_DAYS)
  end

  def start_review!
    @saving_review = true
  end

  def create_claimants!(participant_id:, payee_code:)
    remove_claimants!
    claimants.create_from_intake_data!(participant_id: participant_id, payee_code: payee_code)
  end

  def remove_claimants!
    claimants.destroy_all unless claimants.empty?
  end

  def claimant_participant_id
    return nil if claimants.empty?

    claimants.first.participant_id
  end

  def claimant_not_veteran
    # This is being replaced by veteran_is_not_claimant, but keeping it temporarily
    # until data is backfilled
    claimant_participant_id && claimant_participant_id != veteran.participant_id
  end

  def payee_code
    return nil if claimants.empty?

    claimants.first.payee_code
  end

  def veteran
    @veteran ||= Veteran.find_or_create_by_file_number(veteran_file_number)
  end

  def remove_issues!
    request_issues.destroy_all unless request_issues.empty?
  end

  def mark_rating_request_issues_to_reassociate!
    request_issues.select(&:rating?).each { |ri| ri.update!(rating_issue_associated_at: nil) }
  end

  def serialized_legacy_appeals
    return [] unless legacy_opt_in_enabled?
    return [] unless available_legacy_appeals.any?

    available_legacy_appeals.map do |legacy_appeal|
      {
        vacols_id: legacy_appeal.vacols_id,
        date: legacy_appeal.nod_date,
        eligible_for_soc_opt_in: legacy_appeal.eligible_for_soc_opt_in?(receipt_date),
        issues: legacy_appeal.issues.map(&:intake_attributes)
      }
    end
  end

  def process_legacy_issues!
    LegacyOptinManager.new(decision_review: self).process!
  end

  def on_decision_issues_sync_processed(end_product_establishment)
    # no-op, can be overwritten
  end

  def establish!
    # no-op
  end

  def contestable_issues
    return contestable_issues_from_decision_issues unless can_contest_rating_issues?

    contestable_issues_from_ratings + contestable_issues_from_decision_issues
  end

  def active_nonrating_request_issues
    @active_nonrating_request_issues ||= RequestIssue.nonrating
      .where(veteran_participant_id: veteran.participant_id)
      .where.not(id: request_issues.map(&:id))
      .select(&:status_active?)
  end

  # do not confuse ui_hash with serializer. ui_hash for intake and intakeEdit. serializer for work queue.
  def serializer_class
    ::WorkQueue::DecisionReviewSerializer
  end

  def create_decision_issues_for_tasks(decision_issue_params, decision_date)
    decision_issue_params.each do |decision_issue_param|
      decision_issue_param[:decision_date] = decision_date
      request_issues.find_by(id: decision_issue_param[:request_issue_id])
        .create_decision_issue_from_params(decision_issue_param)
    end
  end

  private

  def can_contest_rating_issues?
    fail Caseflow::Error::MustImplementInSubclass
  end

  def cached_rating_issues
    cached_serialized_ratings.inject([]) do |result, rating_hash|
      result + rating_hash[:issues].map { |rating_issue_hash| RatingIssue.deserialize(rating_issue_hash) }
    end
  end

  def unfiltered_contestable_issues_from_ratings
    return [] unless receipt_date

    cached_rating_issues
      .select { |issue| issue.profile_date && issue.profile_date.to_date < receipt_date }
      .map { |rating_issue| ContestableIssue.from_rating_issue(rating_issue, self) }
  end

  def contestable_issues_from_ratings
    unfiltered_contestable_issues_from_ratings.reject do |contestable_issue|
      contestable_issues_from_decision_issues.any? do |potential_duplicate|
        contestable_issue.rating_issue_reference_id == potential_duplicate.rating_issue_reference_id
      end
    end
  end

  def contestable_decision_issues
    return [] unless receipt_date

    DecisionIssue.where(participant_id: veteran.participant_id, benefit_type: benefit_type)
      .select(&:finalized?)
      .select do |issue|
        issue.approx_decision_date && issue.approx_decision_date < receipt_date
      end
  end

  def contestable_issues_from_decision_issues
    contestable_decision_issues.map { |decision_issue| ContestableIssue.from_decision_issue(decision_issue, self) }
  end

  def available_legacy_appeals
    # If a Veteran does not opt-in to withdraw legacy appeals, do not show inactive appeals
    legacy_opt_in_approved ? matchable_legacy_appeals : active_matchable_legacy_appeals
  end

  def matchable_legacy_appeals
    @matchable_legacy_appeals ||= LegacyAppeal
      .fetch_appeals_by_file_number(veteran_file_number)
      .select { |appeal| appeal.matchable_to_request_issue?(receipt_date) }
  end

  def active_matchable_legacy_appeals
    @active_matchable_legacy_appeals ||= matchable_legacy_appeals.select(&:active?)
  end

  def ratings_with_issues
    return [] unless veteran

    veteran.ratings.reject { |rating| rating.issues.empty? }

    # return empty list when there are no ratings
  rescue Rating::BackfilledRatingError => e
    Raven.capture_exception(e)
    []
  end

  def ratings_cache_key
    # change timestamp in order to clear old cache
    "#{veteran_file_number}-ratings-11282018"
  end

  def formatted_receipt_date
    receipt_date ? receipt_date.to_formatted_s(:short_date) : ""
  end

  def end_product_station
    "499" # National Work Queue
  end

  def validate_receipt_date_not_before_ama
    errors.add(:receipt_date, "before_ama") if receipt_date < self.class.ama_activation_date
  end

  def validate_receipt_date_not_in_future
    errors.add(:receipt_date, "in_future") if Time.zone.today < receipt_date
  end

  def validate_receipt_date
    return unless receipt_date

    validate_receipt_date_not_before_ama
    validate_receipt_date_not_in_future
  end

  def legacy_opt_in_enabled?
    FeatureToggle.enabled?(:intake_legacy_opt_in, user: RequestStore.store[:current_user])
  end
end
